const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('SmartFoundation.Mvc/Views/HousingCommandCenterDashboard/_DashboardDisplayHeartbeat.cshtml','utf8').match(/<script>([\s\S]*)<\/script>/)[1].replace(/@Url.Action\("Heartbeat", "HousingCommandCenterDashboard"\)/g, '/HousingCommandCenterDashboard/Heartbeat');
async function check(responses, terminal) {
 let cleared=0,calls=0;const events={},timers=[];
 const body={appendChild(){},replaceChildren(){cleared++}};
 const document={body,hidden:false,querySelector(){return {value:'test-antiforgery'}},createElement(){return {style:{},setAttribute(){}}},addEventListener(n,fn){events[n]=fn}};
 const location={href:'https://test/HousingCommandCenterDashboard/BuildingDetails?id=3',origin:'https://test',pathname:'/HousingCommandCenterDashboard/BuildingDetails'};
 const window={location,addEventListener(n,fn){events[n]=fn}};window.self=window.top=window;
 vm.runInNewContext(source,{document,window,location,URL,AbortController,setInterval(fn){timers.push(fn)},setTimeout(){return 1},clearTimeout(){},fetch:async()=>{calls++;const r=responses.shift();if(r instanceof Error)throw r;return {status:r}}});
 await new Promise(setImmediate);
 for(let i=0;i<2;i++){await timers[0]();await new Promise(setImmediate)}
 assert.equal(cleared,terminal?1:0);
 if(terminal)assert.equal(calls,1);else assert.equal(calls,3);
}
(async()=>{
 for(const code of [401,403,423]){await check([code],true);console.log('PASS terminal '+code+' hides data and never retries');}
 await check([503,new Error('offline'),204],false);console.log('PASS SQL outage and offline preserve data and recover');
 await check([204,204,204],false);console.log('PASS heartbeat continues successfully');
})().catch(e=>{console.error(e);process.exitCode=1});
