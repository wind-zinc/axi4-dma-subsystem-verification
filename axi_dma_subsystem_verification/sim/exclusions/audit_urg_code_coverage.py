#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Audit every uncovered project code/assertion row in an URG HTML report.

This file intentionally uses the common Python 2.7/Python 3 language subset.
The output is conservative: REVIEW and TEST entries never become waiver
candidates.  Run this again after every directed-test regression because URG
can regroup adjacent toggle bits when their hit patterns change.
"""

import argparse
import errno
import io
import os
import re
import sys
from collections import namedtuple

try:
    from html import unescape as html_unescape
except ImportError:
    from HTMLParser import HTMLParser

    _HTML_PARSER = HTMLParser()

    def html_unescape(value):
        return _HTML_PARSER.unescape(value)


try:
    text_type = unicode
except NameError:
    text_type = str


PROJECT_MODULES = set((
    "axi_dma_subsystem_core",
    "dma_channel_wrap",
    "dma_desc_manager",
    "dma_ctrl_regs",
    "dma_axis_route_ctrl",
    "dma_irq_status_ctrl",
))

Rule = namedtuple(
    "Rule",
    "metric module object_text disposition target evidence",
)
Hole = namedtuple(
    "Hole",
    "metric module object_text detail source_page",
)


def read_text(path):
    with io.open(path, "r", encoding="utf-8", errors="replace") as stream:
        return stream.read()


def plain(fragment):
    fragment = re.sub(r"(?is)<[^>]+>", " ", fragment)
    return re.sub(r"\s+", " ", html_unescape(fragment)).strip()


def cells(row):
    return [
        plain(value)
        for value in re.findall(r"(?is)<t[dh][^>]*>(.*?)</t[dh]>", row)
    ]


def load_rules(path):
    rules = []
    with io.open(path, "r", encoding="utf-8", errors="strict") as stream:
        for line_no, line in enumerate(stream, 1):
            line = line.rstrip(u"\r\n")
            if not line or line.lstrip().startswith(u"#"):
                continue
            row = line.split(u"\t")
            if len(row) != 6:
                raise ValueError(
                    "{0}:{1}: expected 6 TSV fields, got {2}".format(
                        path, line_no, len(row)
                    )
                )
            metric, module, object_text, disposition, target, evidence = row
            rules.append(
                Rule(
                    re.compile(metric),
                    re.compile(module),
                    re.compile(object_text),
                    disposition,
                    target,
                    evidence,
                )
            )
    return rules


def module_pages(report_dir):
    result = {}
    modlist = os.path.join(report_dir, "modlist.html")
    raw = read_text(modlist)
    for match in re.finditer(
        r'(?is)href="(mod\d+\.html)"[^>]*>\s*([^<]+?)\s*</a>', raw
    ):
        page = os.path.join(report_dir, match.group(1))
        name = plain(match.group(2))
        if name in PROJECT_MODULES:
            result[page] = name
    if not result:
        raise ValueError("No project modules found in {0}".format(modlist))
    return result


def extract_toggle_holes(raw, module, page):
    holes = []
    toggle_pos = raw.find('<a name="Toggle">')
    if toggle_pos < 0:
        return holes
    occurrence = {}
    for row_match in re.finditer(
        r"(?is)<tr[^>]*>(.*?)</tr>", raw[toggle_pos:]
    ):
        row_cells = cells(row_match.group(1))
        if len(row_cells) < 4:
            continue
        if row_cells[1] not in ("No", "Yes"):
            continue
        if row_cells[2] not in ("No", "Yes"):
            continue
        if row_cells[1] == "Yes" and row_cells[2] == "Yes":
            continue
        name = row_cells[0]
        if not name or name.startswith(("Total ", "Port ", "Signal ")):
            continue
        occurrence[name] = occurrence.get(name, 0) + 1
        detail = "1->0={0};0->1={1}".format(
            row_cells[1], row_cells[2]
        )
        if len(row_cells) > 4:
            detail += ";kind={0}".format(row_cells[4])
        detail += ";occurrence={0}".format(occurrence[name])
        holes.append(
            Hole("TOGGLE", module, name, detail, os.path.basename(page))
        )
    return holes


def metric_sections(raw, metric):
    """Return definition and per-instance sections for one URG metric."""
    anchor = re.compile(
        r'<a name="(?:inst_tag_\d+_)?'
        + re.escape(metric)
        + r'"></a>'
    )
    any_anchor = re.compile(
        r'<a name="(?:inst_tag_\d+_)?'
        r'(?:Line|Cond|Toggle|FSM|Branch)"></a>'
    )
    result = []
    for match in anchor.finditer(raw):
        next_match = any_anchor.search(raw, match.end())
        end = next_match.start() if next_match else len(raw)
        result.append(raw[match.start():end])
    return result


def extract_line_holes(raw, module, page):
    holes = []
    occurrence = {}
    pattern = re.compile(
        r'^\s*(\d+)\s*<font\s+color\s*=\s*"red">'
        r'\s*0/1\s*==>\s*(.*?)</font>',
        re.MULTILINE,
    )
    for section in metric_sections(raw, "Line"):
        for match in pattern.finditer(section):
            line = int(match.group(1))
            statement = plain(match.group(2))
            key = (line, statement)
            occurrence[key] = occurrence.get(key, 0) + 1
            holes.append(
                Hole(
                    "LINE",
                    module,
                    "L{0} {1}".format(line, statement),
                    "occurrence={0}".format(occurrence[key]),
                    os.path.basename(page),
                )
            )
    return holes


def extract_branch_holes(raw, module, page):
    holes = []
    occurrence = {}
    branch_pattern = re.compile(
        r'(?is)<pre class="code">(.*?)</pre>\s*'
        r'<br clear=all>\s*<span class=repname>Branches:</span>\s*'
        r'<br clear=all>\s*(<table.*?</table>)'
    )
    marker_pattern = re.compile(
        r'<font\s+color\s*=\s*"red">\s*-(\d+)-\s*</font>'
    )
    for section in metric_sections(raw, "Branch"):
        for branch_match in branch_pattern.finditer(section):
            code = branch_match.group(1)
            marker_lines = {}
            for marker in marker_pattern.finditer(code):
                prior_lines = re.findall(
                    r'(?m)^\s*(\d+)\s+', code[:marker.start()]
                )
                marker_lines[marker.group(1)] = (
                    prior_lines[-1] if prior_lines else "?"
                )

            table = branch_match.group(2)
            header_match = re.search(r"(?is)<tr[^>]*>(.*?)</tr>", table)
            if not header_match:
                continue
            headers = [
                plain(value)
                for value in re.findall(
                    r"(?is)<th[^>]*>(.*?)</th>", header_match.group(1)
                )
            ]
            for row_match in re.finditer(
                r'(?is)<tr[^>]*class="[^"]*uRed[^"]*"[^>]*>'
                r'(.*?)</tr>',
                table,
            ):
                row_cells = cells(row_match.group(1))
                if not row_cells or row_cells[-1] != "Not Covered":
                    continue
                active = []
                for heading, value in zip(headers, row_cells):
                    if not heading.startswith("-") or value in ("", "-"):
                        continue
                    marker = heading.strip("-")
                    active.append(
                        "{0}@L{1}={2}".format(
                            heading, marker_lines.get(marker, "?"), value
                        )
                    )
                object_text = ";".join(active)
                occurrence[object_text] = occurrence.get(object_text, 0) + 1
                holes.append(
                    Hole(
                        "BRANCH",
                        module,
                        object_text,
                        "occurrence={0}".format(occurrence[object_text]),
                        os.path.basename(page),
                    )
                )
    return holes


def extract_condition_holes(raw, module, page):
    holes = []
    pattern = re.compile(
        r'(?is)<pre class="code">\s*LINE\s+(\d+)\s+'
        r'EXPRESSION\s+([^\r\n]+).*?</pre>\s*'
        r'<table[^>]*>(.*?)</table>'
    )
    occurrence = {}
    for match in pattern.finditer(raw):
        line = int(match.group(1))
        expression = plain(match.group(2))
        for row_match in re.finditer(
            r'(?is)<tr[^>]*class="[^"]*uRed[^"]*"[^>]*>(.*?)</tr>',
            match.group(3),
        ):
            row_cells = cells(row_match.group(1))
            if not row_cells or row_cells[-1] != "Not Covered":
                continue
            vector = "".join(row_cells[:-1])
            key = (line, expression, vector)
            occurrence[key] = occurrence.get(key, 0) + 1
            holes.append(
                Hole(
                    "COND",
                    module,
                    "L{0} {1} VECTOR={2}".format(
                        line, expression, vector
                    ),
                    "occurrence={0}".format(occurrence[key]),
                    os.path.basename(page),
                )
            )
    return holes


def extract_fsm_holes(raw, module, page):
    holes = []
    occurrence = {}
    for row_match in re.finditer(r"(?is)<tr[^>]*>(.*?)</tr>", raw):
        row_cells = cells(row_match.group(1))
        if len(row_cells) < 3:
            continue
        transition = row_cells[0]
        if "->" not in transition or row_cells[-1] != "Not Covered":
            continue
        occurrence[transition] = occurrence.get(transition, 0) + 1
        holes.append(
            Hole(
                "FSM",
                module,
                transition,
                "line={0};occurrence={1}".format(
                    row_cells[1], occurrence[transition]
                ),
                os.path.basename(page),
            )
        )
    return holes


def source_module(source_path):
    filename = re.split(r"[/\\]", source_path)[-1]
    return filename.rsplit(".", 1)[0]


def assertion_section(raw, start_text, end_text):
    start = raw.find(start_text)
    if start < 0:
        return ""
    end = raw.find(end_text, start + len(start_text))
    return raw[start:end if end >= 0 else len(raw)]


def extract_assertion_holes(report_dir):
    page = os.path.join(report_dir, "asserts.html")
    if not os.path.isfile(page):
        return []
    raw = read_text(page)
    holes = []

    uncovered = assertion_section(
        raw, "Assertions Uncovered:", "Assertions Success:"
    )
    for row_match in re.finditer(
        r'(?is)<tr[^>]*class="wht"[^>]*>(.*?)</tr>', uncovered
    ):
        row = row_match.group(1)
        row_cells = cells(row)
        if len(row_cells) < 7:
            continue
        source_match = re.search(
            r'(?is)<a\s+title="([^"]+)"[^>]*>'
            r'<img\s+class="sourcefile"',
            row,
        )
        if not source_match:
            continue
        source = html_unescape(source_match.group(1))
        try:
            failures = int(row_cells[5])
        except ValueError:
            failures = 0
        metric = "ASSERT_FAIL" if failures else "ASSERT"
        holes.append(
            Hole(
                metric,
                source_module(source),
                row_cells[0],
                (
                    "attempts={0};successes={1};failures={2};"
                    "incomplete={3};source={4}"
                ).format(
                    row_cells[3], row_cells[4], row_cells[5],
                    row_cells[6], source
                ),
                os.path.basename(page),
            )
        )

    failures_section = assertion_section(
        raw, "Assertions Failure:", "Assertions Incomplete:"
    )
    existing_failures = set(
        hole.object_text
        for hole in holes
        if hole.metric == "ASSERT_FAIL"
    )
    for row_match in re.finditer(
        r'(?is)<tr[^>]*class="wht"[^>]*>(.*?)</tr>', failures_section
    ):
        row = row_match.group(1)
        row_cells = cells(row)
        if len(row_cells) < 7 or row_cells[0] in existing_failures:
            continue
        source_match = re.search(
            r'(?is)<a\s+title="([^"]+)"[^>]*>'
            r'<img\s+class="sourcefile"',
            row,
        )
        if not source_match:
            continue
        source = html_unescape(source_match.group(1))
        holes.append(
            Hole(
                "ASSERT_FAIL",
                source_module(source),
                row_cells[0],
                (
                    "attempts={0};successes={1};failures={2};"
                    "incomplete={3};source={4}"
                ).format(
                    row_cells[3], row_cells[4], row_cells[5],
                    row_cells[6], source
                ),
                os.path.basename(page),
            )
        )

    uncovered_covers = assertion_section(
        raw, "Cover Properties Uncovered:", "Cover Properties Matches:"
    )
    for row_match in re.finditer(
        r'(?is)<tr[^>]*class="wht"[^>]*>(.*?)</tr>', uncovered_covers
    ):
        row = row_match.group(1)
        row_cells = cells(row)
        if len(row_cells) < 6:
            continue
        source_match = re.search(
            r'(?is)<a\s+title="([^"]+)"[^>]*>'
            r'<img\s+class="sourcefile"',
            row,
        )
        if not source_match:
            continue
        source = html_unescape(source_match.group(1))
        holes.append(
            Hole(
                "COVER",
                source_module(source),
                row_cells[0],
                "attempts={0};matches={1};incomplete={2};source={3}".format(
                    row_cells[3], row_cells[4], row_cells[5], source
                ),
                os.path.basename(page),
            )
        )
    return holes


def regex_fullmatch(pattern, value):
    match = pattern.match(value)
    return match is not None and match.end() == len(value)


def classify(hole, rules):
    for rule in rules:
        if (
            regex_fullmatch(rule.metric, hole.metric)
            and regex_fullmatch(rule.module, hole.module)
            and regex_fullmatch(rule.object_text, hole.object_text)
        ):
            return rule
    raise ValueError(
        "No rule matched {0} {1} {2}".format(
            hole.metric, hole.module, hole.object_text
        )
    )


def make_parent(path):
    parent = os.path.dirname(os.path.abspath(path))
    if os.path.isdir(parent):
        return
    try:
        os.makedirs(parent)
    except OSError as error:
        if error.errno != errno.EEXIST or not os.path.isdir(parent):
            raise


def clean_tsv_field(value):
    if not isinstance(value, text_type):
        value = text_type(value)
    return value.replace(u"\t", u" ").replace(u"\r", u" ").replace(
        u"\n", u" "
    )


def write_tsv(path, header, rows):
    make_parent(path)
    # Disable platform newline translation so generated review artifacts use
    # Linux LF on both Python 2.7 and Python 3.
    with io.open(path, "w", encoding="utf-8", newline="") as stream:
        stream.write(u"\t".join(clean_tsv_field(item) for item in header))
        stream.write(u"\n")
        for row in rows:
            stream.write(u"\t".join(clean_tsv_field(item) for item in row))
            stream.write(u"\n")


def console_write(stream, message):
    message = text_type(message)
    if sys.version_info[0] < 3:
        stream.write(message.encode("utf-8"))
    else:
        stream.write(message)


def main():
    default_rules = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "subsystem_coverage_rules.tsv",
    )
    parser = argparse.ArgumentParser()
    parser.add_argument("report_dir")
    parser.add_argument("--rules", default=default_rules)
    parser.add_argument("--output", required=True)
    parser.add_argument("--waiver-candidates")
    args = parser.parse_args()

    rules = load_rules(args.rules)
    holes = []
    for page, module in sorted(module_pages(args.report_dir).items()):
        raw = read_text(page)
        holes.extend(extract_line_holes(raw, module, page))
        holes.extend(extract_condition_holes(raw, module, page))
        holes.extend(extract_toggle_holes(raw, module, page))
        holes.extend(extract_fsm_holes(raw, module, page))
        holes.extend(extract_branch_holes(raw, module, page))
    holes.extend(extract_assertion_holes(args.report_dir))

    rows = []
    waiver_rows = []
    counts = {
        "TEST": 0,
        "WAIVE": 0,
        "SCOPE": 0,
        "REVIEW": 0,
    }
    for hole in holes:
        rule = classify(hole, rules)
        counts[rule.disposition] = counts.get(rule.disposition, 0) + 1
        row = [
            hole.metric,
            hole.module,
            hole.object_text,
            hole.detail,
            rule.disposition,
            rule.target,
            rule.evidence,
            hole.source_page,
        ]
        rows.append(row)
        if rule.disposition == "WAIVE":
            waiver_rows.append(row)

    header = [
        "metric",
        "module",
        "object",
        "detail",
        "disposition",
        "target",
        "evidence",
        "source_page",
    ]
    write_tsv(args.output, header, rows)
    if args.waiver_candidates:
        write_tsv(args.waiver_candidates, header, waiver_rows)

    console_write(
        sys.stdout,
        (
            "Audited {0} uncovered rows: TEST={1} WAIVE={2} "
            "SCOPE={3} REVIEW={4}\n"
        ).format(
            len(holes),
            counts.get("TEST", 0),
            counts.get("WAIVE", 0),
            counts.get("SCOPE", 0),
            counts.get("REVIEW", 0),
        ),
    )
    console_write(sys.stdout, "Full audit: {0}\n".format(args.output))
    if args.waiver_candidates:
        console_write(
            sys.stdout,
            "Approved waiver candidates: {0}\n".format(
                args.waiver_candidates
            ),
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (IOError, OSError, ValueError) as error:
        console_write(sys.stderr, "ERROR: {0}\n".format(error))
        raise SystemExit(2)
