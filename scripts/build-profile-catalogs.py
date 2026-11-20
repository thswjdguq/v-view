"""Build offline name suggestions from downloaded public datasets; no credentials."""
import argparse
import csv
import hashlib
import io
import json
from collections import defaultdict
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--schools', type=Path, required=True, help='Official standard.json download')
parser.add_argument('--certifications', type=Path, required=True, help='Official 15112802 CSV download')
parser.add_argument('--retrieved-at', required=True)
args = parser.parse_args()
destination = Path(__file__).resolve().parents[1] / 'v_view/assets/catalogs'
destination.mkdir(parents=True, exist_ok=True)

schools = defaultdict(set)
for row in json.loads(args.schools.read_text(encoding='utf-8')):
    name = row['SCHL_NM'].strip()
    if name:
        schools[name].add(' · '.join(filter(None, [row.get('CTPV_NM'), row.get('SCHL_SE_NM')])))
school_aliases = {'한국과학기술원': ['KAIST', '카이스트'], '포항공과대학교': ['POSTECH', '포스텍'], '울산과학기술원': ['UNIST', '유니스트'], '광주과학기술원': ['GIST', '지스트'], '대구경북과학기술원': ['DGIST', '디지스트']}
school_entries = [{'name': name, 'detail': ' / '.join(sorted(details)), 'aliases': list(dict.fromkeys(([name.replace('대학교', '대')] if '대학교' in name else []) + school_aliases.get(name, [])))} for name, details in sorted(schools.items())]

raw = args.certifications.read_bytes()
try:
    text = raw.decode('utf-8-sig')
except UnicodeDecodeError:
    text = raw.decode('cp949')
certifications = defaultdict(set)
for row in csv.DictReader(io.StringIO(text)):
    name = row['종목명'].strip()
    if name:
        certifications[name].add(row['자격구분'].strip())
cert_aliases = {'정보처리기사': ['정처기'], '정보처리산업기사': ['정처산기'], 'SQL 개발자(SQLD)': ['SQLD', 'SQL개발자'], 'SQL 전문가(SQLP)': ['SQLP', 'SQL전문가'], '데이터분석 준전문가(ADsP)': ['ADsP', '데이터분석준전문가'], '데이터분석 전문가(ADP)': ['ADP', '데이터분석전문가']}
for name in ['SQL 개발자(SQLD)', 'SQL 전문가(SQLP)', '데이터분석 준전문가(ADsP)', '데이터분석 전문가(ADP)']:
    certifications[name].add('한국데이터산업진흥원 자격')
cert_entries = [{'name': name, 'detail': ' · '.join(sorted(details)), 'aliases': cert_aliases.get(name, []) + ([name.replace('컴퓨터활용능력', '컴활')] if '컴퓨터활용능력' in name else [])} for name, details in sorted(certifications.items())]
presets = ['정보처리기사', '정보처리산업기사', '정보처리기능사', 'SQL 개발자(SQLD)', '데이터분석 준전문가(ADsP)', '정보보안기사', '정보보안산업기사']
for entry in cert_entries:
    if entry['name'] in presets:
        entry['sortOrder'] = presets.index(entry['name'])

for filename, entries, source, source_date, raw_path in [
    ('schools', school_entries, 'https://www.data.go.kr/data/15107736/standard.do', '2026-03-18 (reference year 2025)', args.schools),
    ('certifications', cert_entries, 'https://www.data.go.kr/data/15112802/fileData.do', '2023-03-16; includes historical names', args.certifications),
]:
    value = {'source': source, 'sourceDate': source_date, 'retrievedAt': args.retrieved_at, 'sourceSha256': hashlib.sha256(raw_path.read_bytes()).hexdigest(), 'entries': entries}
    if filename == 'certifications':
        value['supplementSources'] = ['https://www.dataq.or.kr/www/dataq_brochure_2022.pdf']
    (destination / (filename + '.json')).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(filename, len(entries))
