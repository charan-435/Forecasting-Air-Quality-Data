from pathlib import Path
import csv,zipfile,xml.etree.ElementTree as E,os
p=Path('ATSA_Presentation.pptx')
rows=list(csv.DictReader(open('results/paper/scores.csv')))
scores={(r['sensor'],r['horizon'],r['method']):float(r['MASE']) for r in rows if r['pollutant']=='PM2.5'}
ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main','p':'http://schemas.openxmlformats.org/presentationml/2006/main'}
for prefix,uri in ns.items():E.register_namespace(prefix,uri)
with zipfile.ZipFile(p) as z:
 items={i.filename:(i,z.read(i.filename)) for i in z.infolist()}
root=E.fromstring(items['ppt/slides/slide18.xml'][1])
replace={
'Evaluation and Results':'Recorded Model Results',
'Baselines: RNN, LGBM, TCN, TFT, Transformer, XGB, CatBoost':'Recorded recursive forecasts; seasonality S = 24',
'•  CPCB: strongest at 14 and 31 days for most pollutants':'•  Same recorded run as the R document',
'•  CPCB 7 days: comparable with LGBM, XGB, CatBoost':'•  CPCB 1-day: WaveCatBoost is lowest here',
'•  CPCB 1 day: competitive with Transformer models':'•  CPCB: the best model varies with horizon',
'•  ID1: strong across horizons and pollutants':'•  ID1: WaveCatBoost is lowest at 1 and 7 days',
'•  Exception: SO2, where XGB and CatBoost stay competitive':'•  Winner depends on station and horizon',
'PM2.5 MASE (from Table 1)':'PM2.5 MASE (recorded results)',
'PM2.5 MASE (scores.csv)':'PM2.5 MASE (recorded results)',
'Bold = best in row. CPCB 1-day best is TCN (2.50).':'Bold = lowest unrounded score among shown models.'}
for t in root.findall('.//a:t',ns):
 if t.text in replace:t.text=replace[t.text]
for tr in root.findall('.//a:tbl/a:tr',ns)[1:]:
 cells=tr.findall('a:tc',ns)
 get=lambda c:''.join(t.text or '' for t in c.findall('.//a:t',ns))
 sensor=get(cells[0]);h=get(cells[1]).replace(' ','')
 values=[scores[sensor,h,m] for m in ['xgb','catboost','wavecatboost']]
 for c,v in zip(cells[2:],values):
  ts=c.findall('.//a:t',ns);ts[0].text=f'{v:.2f}'
  for t in ts[1:]:t.text=''
  for r in c.findall('.//a:r',ns):
   props=r.find('a:rPr',ns)
   if props is None:props=E.Element('{'+ns['a']+'}rPr');r.insert(0,props)
   props.set('b','1' if v==min(values) else '0')
new=E.tostring(root,encoding='utf-8',xml_declaration=True)
tmp=p.with_suffix('.updated.pptx')
with zipfile.ZipFile(tmp,'w') as z:
 for name,(info,data) in items.items():z.writestr(info,new if name=='ppt/slides/slide18.xml' else data)
os.replace(tmp,p)
print('Updated 24 native PowerPoint score cells and their labels.')
