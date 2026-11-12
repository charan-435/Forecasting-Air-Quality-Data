"""Validate recorded scores and displayed result tables; never fits models."""
import csv, json, math, re
from pathlib import Path
from collections import defaultdict
ROOT = Path(__file__).resolve().parents[2]
def read(p):
    with (ROOT/p).open(encoding='utf-8-sig',newline='') as f: return list(csv.DictReader(f))
def text(p): return (ROOT/p).read_text(encoding='utf-8-sig')
def js(p): return json.loads(text('presentation/webapp/js/data/'+p+'.js').split('=',1)[1].strip().rstrip(';'))
count=0
def eq(a,b,label,tol=1e-9):
    global count
    assert math.isclose(float(a),float(b),abs_tol=tol,rel_tol=0),f'{label}: {a} != {b}'
    count+=1
def key(r): return tuple(r[k] for k in ['sensor','pollutant','horizon','method'])
scores={key(r):r for r in read('results/paper/scores.csv')}
web=js('scores');assert len(web)==len(scores)
for row in web:
    for m in ['MASE','MAE','RMSE']:eq(row[m],scores[key(row)][m],f'Web {key(row)} {m}')
for r in js('paper_cmp'):
    for m,c in dict(xgb='ours_xgb',lgb='ours_lgb',catboost='ours_cat',wavecatboost='ours_wave').items():eq(r[c],scores[(r['sensor'],r['pollutant'],r['horizon'],m)]['MASE'],'Published comparison / our score')
rmd=text('analysis.Rmd');assert '"results", "illustrative"' not in rmd
assert '"results", "paper", "scores.csv"' in rmd
metrics=[r for r in read('results/shillong/architecture/LEVEL_METRICS.csv') if r['station']=='Lumpyngngad' and r['target']=='PM2.5' and r['block']=='test']
lgb={(r['arch'],int(r['horizon_h'])):float(r['MAE']) for r in metrics if r['family']=='lightgbm'}
hs=[24,168,336,744]
def question(n): return re.search(rf'^####? Q{n}\..*?(?=^####? Q\d+\.|\Z)',rmd,re.M|re.S).group()
def mdrows(s):
    return [[c.strip().replace('**','').replace('\\*','') for c in line.split('|')[1:-1]] for line in s.splitlines() if line.startswith('|')]
for row in mdrows(question(1)):
    if len(row)==5 and (row[0],24) in lgb:
        for h,v in zip(hs,row[1:]):eq(v,f'{lgb[row[0],h]:.2f}',f'Q1 {row[0]} {h}')
row=next(r for r in mdrows(question(2)) if r[0]=='Whole series')
for v,k in zip(row[1:],[('B0',24),('B0',168),('B0',336),('B0',744),('C2_sep',168),('C2_sep',744)]):eq(v,f'{lgb[k]:.2f}','Q2 whole series')
for row in mdrows(question(5)):
    pair=re.match(r'(\w+) vs (\w+)',row[0])
    if pair:
        a,b=pair.groups()
        for h,v in zip(hs,row[1:]):eq(v,f'{lgb[a,h]/lgb[b,h]:.2f}',f'Q5 {a}/{b} {h}')
groups=defaultdict(list)
for r in metrics:
    if r['arch'] in ['A0','A3','B0','C3_sh'] and r['family']!='reference':groups[(r['arch'],r['horizon_h'])].append(r)
ranks=defaultdict(list);wins=defaultdict(int)
for group in groups.values():
    for r in group:
        v=float(r['MAE']);rank=1+sum(float(x['MAE'])<v for x in group)+(sum(float(x['MAE'])==v for x in group)-1)/2
        ranks[r['family']].append(rank)
        if rank==1:wins[r['family']]+=1
for f,label in dict(elasticnet='elastic net',lasso='lasso',ridge='ridge',catboost='CatBoost',lightgbm='LightGBM',xgboost='XGBoost').items():
    value=f'{sum(ranks[f])/len(ranks[f]):.2f}'
    assert f'{label} {value}' in question(8),(f,value)
    assert f'{label} {wins[f]}' in question(8),(f,wins[f])
best=[r for r in read('results/shillong/architecture/BEST_BY_HORIZON.csv') if r['station']=='Lumpyngngad']
assert f"{sum(r['best_overall']==r['test_best_arch_oracle'] for r in best)} of {len(best)} saved cells" in question(9)
direct={(r['model'],int(r['h'])):float(r['MAE']) for r in read('results/shillong/direct_scores.csv')}
models={'Persistence':'persistence','LightGBM, lags only':'LGB-lags','+ calendar':'LGB-lags+cal','+ ERA5 at the forecast origin':'LGB+ERA5','+ station weather':'LGB+station-met','+ neighbour-station PM2.5':'LGB+neighbour','+ causal Haar bands':'LGB+causal-Haar','+ future ERA5 (oracle)':'LGB+ERA5-oracle'}
for row in mdrows(question(14)):
    if row[0] in models:
        for h,v in zip([1,6,24],row[1:]):eq(v,f'{direct[models[row[0]],h]:.2f}',f'Q14 {row[0]} {h}')
clean=read('results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv')
for row in mdrows(question(15)):
    m=row[0].split()[0]
    if m in ['B0','A1','B1','B2','B3']:
        for dataset,v in zip(['clean','unmasked'],row[1:]):
            r=next(r for r in clean if r['dataset']==dataset and r['model']==m and r['block']=='test')
            eq(v,f"{float(r['MAE']):.2f}",f'Q15 {m} {dataset}')
tex=text('presentation/segments/4_conclude.tex');methods=['snaive','sarima','lgb','catboost','wavecatboost']
for sensor,body in re.findall(r'^\s*(CPCB|ID1) & (.*?)\\\\',tex,re.M):
    values=re.findall(r'\d+\.\d+',body)
    if len(values)==5:
        for m,v in zip(methods,values):eq(v,f"{float(scores[sensor,'PM2.5','1d',m]['MASE']):.2f}",'Slide 14 table')
chart=re.search(r'\\foreach \\x/\\a/\\b in \{(.*?)\}',tex).group(1)
for m,entry in zip(methods,chart.split(',')):
    _,a,b=entry.split('/')
    for sensor,v in [('CPCB',a),('ID1',b)]:eq(v,f"{float(scores[sensor,'PM2.5','1d',m]['MASE']):.2f}",'Slide 14 plot')
tex=text('presentation/segments/6_extensions.tex')
for label,f in [('CatBoost','catboost'),('LightGBM','lightgbm'),('XGBoost','xgboost')]:
    values=next(v for v in [re.findall(r'\d+\.\d+',r) for r in re.findall(rf'{label} & ([^\n]+)',tex)] if len(v)==4)
    for h,v in zip(hs,values):
        r=next(r for r in metrics if r['arch']=='A3' and r['family']==f and int(r['horizon_h'])==h)
        eq(v,f"{float(r['MAE']):.2f}",f'Slide 30 {label} {h}')
# The saved wide table must mirror every available MASE score.
for row in read('results/paper/mase_wide.csv'):
    for m,v in row.items():
        if m not in ['sensor','pollutant','horizon'] and v and v != 'NA':
            eq(v,scores[(row['sensor'],row['pollutant'],row['horizon'],m)]['MASE'],'mase_wide.csv')

# Check all filter and Fourier score cells in the PDF's LaTeX source.
tex=text('presentation/segments/6_extensions.tex').split('\\subsection{Shillong')[0]
tex=re.sub(r'\\textbf\{([^}]*)\}',r'\1',tex)
for before,after in [('PM$_{2.5}$','PM2.5'),('PM$_{10}$','PM10'),('NO$_2$','NO2'),('SO$_2$','SO2'),('O$_3$','O3')]:tex=tex.replace(before,after)
a,b=tex.split('\\subsection{Fourier comparison}')
f=read('results/extensions/filter_scores.csv');e=read('results/extensions/extension_scores.csv')
for sensor,pol,h,d,l in re.findall(r'(CPCB|ID1)\s*&\s*([A-Z0-9.]+)\s*&\s*([\d.]+)\s*&\s*([\d.]+)\s*&\s*([\d.]+)',a):
    for name,v in [('haar',h),('d4',d),('la8',l)]:
        r=next(r for r in f if r['sensor']==sensor and r['pollutant']==pol and r['filter']==name and r['method']=='wavecatboost')
        eq(v,f"{float(r['MASE']):.3f}",'Filter slide')
for sensor,pol,h,four in re.findall(r'(CPCB|ID1)\s*&\s*([A-Z0-9.]+)\s*&\s*([\d.]+)\s*&\s*([\d.]+)',b):
    for name,v in [('haar',h),('fourier',four)]:
        r=next(r for r in e if r['sensor']==sensor and r['pollutant']==pol and r['filter']==name and r['method']=='wavelgb')
        eq(v,f"{float(r['MASE']):.3f}",'Fourier slide')
print(f'PASS: {count} numeric comparisons plus source, ranking and provenance checks.')

