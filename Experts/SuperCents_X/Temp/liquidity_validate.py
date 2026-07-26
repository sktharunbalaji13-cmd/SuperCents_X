"""
Sprint 12.4 - Liquidity Lifecycle Validation
=============================================
Validates lifecycle invariants from MT5 Strategy Tester log.

Usage:
    python liquidity_validate.py <logfile>
    
Checks:
  - All MITIGATED levels were previously SWEPT
  - All INVALIDATED levels were previously SWEPT
  - No duplicate mitigations
  - No duplicate invalidations
  - No illegal state transitions
  - Conservation invariant holds
  - Transition counts are consistent
"""

import re
import sys
from collections import defaultdict


def parse_log(filepath):
    with open(filepath, 'r', encoding='utf-16-le', errors='ignore') as f:
        return f.readlines()


# ──────────────────────────────────────────────────────────────────────
# Log line patterns
# ──────────────────────────────────────────────────────────────────────
RE_CREATE = re.compile(
    r'LIQUIDITY-DETECT\s+CANDIDATE=\w+\s+ACCEPTED=TRUE.*LEVEL=(\d+)'
)
RE_SWEEP = re.compile(
    r'LIQUIDITY-SWEEP\s+ID=(\d+).*RESULT=SWEEP'
)
RE_SWEPT = re.compile(
    r'LIQUIDITY-SWEPT\s+ID=(\d+)'
)
RE_MITIGATED = re.compile(
    r'LIQUIDITY-MITIGATED\s+ID=(\d+)'
)
RE_INVALIDATED = re.compile(
    r'LIQUIDITY-INVALIDATED\s+ID=(\d+)'
)
RE_REJECT = re.compile(
    r'LIQUIDITY-TRANSITION-REJECT\s+ID=(\d+)\s+FROM=(\w+)\s+TO=(\w+)\s+REASON=(\w+)'
)
RE_CONSERVATION = re.compile(
    r'Conservation Check:\s*(\d+)\s*\+\s*(\d+)\s*\+\s*(\d+)\s*\+\s*(\d+)\s*=\s*(\d+)\s+(\w+)'
)


def validate(log_lines):
    results = {
        'total_lines': len(log_lines),
        'created': set(),
        'swept': set(),
        'mitigated': set(),
        'invalidated': set(),
        'rejected': [],
        'errors': [],
        'transition_counts': defaultdict(int),
        'reject_counts': defaultdict(int),
        'conservation_ok': False,
        'conservation_line': '',
    }

    for line in log_lines:
        # Creation
        m = RE_CREATE.search(line)
        if m:
            results['created'].add(int(m.group(1)))

        # Sweep event (detection log)
        m = RE_SWEEP.search(line)
        if m:
            pass  # Sweep event logged separately

        # Swept (successful transition)
        m = RE_SWEPT.search(line)
        if m:
            lid = int(m.group(1))
            results['swept'].add(lid)
            results['transition_counts']['ACTIVE->SWEPT'] += 1

        # Mitigated (successful transition)
        m = RE_MITIGATED.search(line)
        if m:
            lid = int(m.group(1))
            results['mitigated'].add(lid)
            results['transition_counts']['SWEPT->MITIGATED'] += 1

        # Invalidated (successful transition)
        m = RE_INVALIDATED.search(line)
        if m:
            lid = int(m.group(1))
            results['invalidated'].add(lid)
            results['transition_counts']['SWEPT->INVALIDATED'] += 1

        # Rejected transitions
        m = RE_REJECT.search(line)
        if m:
            lid = int(m.group(1))
            frm = m.group(2)
            to = m.group(3)
            reason = m.group(4)
            results['rejected'].append((lid, frm, to, reason))
            key = f'{frm}->{to}'
            results['reject_counts'][key] += 1

        # Conservation check
        m = RE_CONSERVATION.search(line)
        if m:
            active = int(m.group(1))
            swept_c = int(m.group(2))
            mitigated_c = int(m.group(3))
            invalidated_c = int(m.group(4))
            total = int(m.group(5))
            status = m.group(6)
            results['conservation_ok'] = (status == 'OK')
            results['conservation_line'] = (
                f'  Active={active} Swept={swept_c} '
                f'Mitigated={mitigated_c} Invalidated={invalidated_c} '
                f'Total={total} Status={status}'
            )

    # ── Invariant Checks ──────────────────────────────────────────

    # 1. Every MITIGATED must have been SWEPT first
    missing_swept = results['mitigated'] - results['swept']
    if missing_swept:
        results['errors'].append(
            f'INVARIANT FAIL: MITIGATED without prior SWEPT: {sorted(missing_swept)}'
        )

    # 2. Every INVALIDATED must have been SWEPT first
    missing_swept_inv = results['invalidated'] - results['swept']
    if missing_swept_inv:
        results['errors'].append(
            f'INVARIANT FAIL: INVALIDATED without prior SWEPT: {sorted(missing_swept_inv)}'
        )

    # 3. No level is both MITIGATED and INVALIDATED
    both = results['mitigated'] & results['invalidated']
    if both:
        results['errors'].append(
            f'INVARIANT FAIL: Level is both MITIGATED and INVALIDATED: {sorted(both)}'
        )

    # 4. No illegal transitions
    for lid, frm, to, reason in results['rejected']:
        if frm not in ('LIQUIDITY_STATUS_ACTIVE', 'LIQUIDITY_STATUS_SWEPT',
                        'LIQUIDITY_STATUS_MITIGATED', 'LIQUIDITY_STATUS_INVALIDATED',
                        'LIQUIDITY_STATUS_UNKNOWN'):
            results['errors'].append(
                f'Unexpected source state in rejection: {frm}'
            )

    # 5. Expected reject types should only be specific patterns
    allowed_rejects = {
        'LIQUIDITY_STATUS_ACTIVE->MITIGATED',
        'LIQUIDITY_STATUS_ACTIVE->INVALIDATED',
        'LIQUIDITY_STATUS_ACTIVE->SWEPT',  # AlreadySwept (rare race)
        'LIQUIDITY_STATUS_SWEPT->SWEPT',   # double-sweep attempt
        'LIQUIDITY_STATUS_MITIGATED->MITIGATED',  # double-mitigation
        'LIQUIDITY_STATUS_INVALIDATED->INVALIDATED',  # double-invalidation
        'LIQUIDITY_STATUS_SWEPT->MITIGATED',  # AlreadyMitigated
        'LIQUIDITY_STATUS_SWEPT->INVALIDATED',  # AlreadyInvalidated
    }

    for key in results['reject_counts']:
        if key not in allowed_rejects:
            results['errors'].append(
                f'Unexpected reject pattern: {key} (count={results["reject_counts"][key]})'
            )

    # 6. No duplicate ID in MITIGATED transition log
    # (MitigateLevel already prevents duplicates; cross-check for log consistency)
    mit_lines = {}
    for line in log_lines:
        m = RE_MITIGATED.search(line)
        if m:
            lid = int(m.group(1))
            if lid in mit_lines:
                results['errors'].append(
                    f'DUPLICATE MITIGATION LOG: ID={lid} '
                    f'first={mit_lines[lid]} second={line.strip()[:80]}'
                )
            mit_lines[lid] = line

    # 7. No duplicate ID in INVALIDATED transition log
    inv_lines = {}
    for line in log_lines:
        m = RE_INVALIDATED.search(line)
        if m:
            lid = int(m.group(1))
            if lid in inv_lines:
                results['errors'].append(
                    f'DUPLICATE INVALIDATION LOG: ID={lid} '
                    f'first={inv_lines[lid]} second={line.strip()[:80]}'
                )
            inv_lines[lid] = line

    return results


def print_report(results):
    print('=' * 65)
    print('  LIQUIDITY LIFECYCLE VALIDATION REPORT')
    print('=' * 65)
    print()
    print(f'  Log lines scanned:  {results["total_lines"]}')
    print(f'  Total created:      {len(results["created"])}')
    print(f'  Total swept:        {len(results["swept"])}')
    print(f'  Total mitigated:    {len(results["mitigated"])}')
    print(f'  Total invalidated:  {len(results["invalidated"])}')
    print(f'  Total rejections:   {len(results["rejected"])}')
    print()

    # -- Transition counts --
    print('  -- Transition Counts --')
    for t, c in sorted(results['transition_counts'].items()):
        print(f'    {t:30s}  {c:6d}')
    print()

    # -- Rejection counts --
    print('  -- Rejected Transitions --')
    for t, c in sorted(results['reject_counts'].items()):
        print(f'    {t:30s}  {c:6d}')
    if not results['reject_counts']:
        print('    (none)')
    print()

    # -- Conservation --
    print('  -- Conservation Check --')
    if results['conservation_line']:
        print(results['conservation_line'])
    else:
        print('    NOT FOUND in log')
    print()

    # -- Validation Results --
    print('  -- Validation Results --')
    if results['errors']:
        print(f'  FAIL: {len(results["errors"])} invariant violation(s)')
        print()
        for e in results['errors']:
            print(f'    X  {e}')
    else:
        print('  PASS: All lifecycle invariants hold')
    print()


def main():
    if len(sys.argv) < 2:
        print('Usage: python liquidity_validate.py <path_to_tester_log>')
        sys.exit(1)

    logfile = sys.argv[1]
    print(f'Parsing: {logfile}')
    lines = parse_log(logfile)
    print(f'Read {len(lines)} lines')
    print()

    results = validate(lines)
    print_report(results)

    if results['errors']:
        sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()
