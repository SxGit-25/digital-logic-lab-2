from pathlib import Path
import json
here=Path(__file__).resolve().parent
verified=json.loads((here/'final_verification.json').read_text())
assert verified['result']=='PASS'
data=json.loads((here/'summary_data.json').read_text(encoding='utf-8'))
data['draft']=False
data['notes']='第4至7项均完成针对性修复及seed 1–8尝试后仍超限，已回退；未删除原功能。失败Fitter无法建立拟合时序网表，report_timing拒绝日志已保留，未冒报最差10条路径。'
for item in data['items'][3:]:
    step=int(item[0].split()[0])
    cp=json.loads((here.parent/f'step{step}/checkpoint.json').read_text(encoding='utf-8'))
    least=min(t['le_required'] for t in cp['attempts'])
    item[2]=f'Fitter最少需{least} LE，超过1270；修复及seed 1–8后回退。'
data['items'][3][2]+='未改OR。'
cp=json.loads((here.parent/'step3/checkpoint.json').read_text(encoding='utf-8'))
data['pofs'][3]={'step':3,'name':cp['pof']}
(here/'summary_data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS final summary inputs verified against all checkpoints')
