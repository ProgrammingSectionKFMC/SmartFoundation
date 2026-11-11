const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('SmartFoundation.Mvc/Views/HousingCommandCenterDashboard/_DashboardDisplayHeartbeat.cshtml','utf8').match(/<script>([\s\S]*)<\/script>/)[1].replace(/@Url.Action\("Heartbeat", "HousingCommandCenterDashboard"\)/g,'/HousingCommandCenterDashboard/Heartbeat');
async function check(valid,finalStatus){
 const timers=[],frames=[];let removed=0,cleared=0,calls=0;
 const location={href:'https://test/HousingCommandCenterDashboard/Department?id=3',origin:'https://test',pathname:'/HousingCommandCenterDashboard/Department'};
 const window={location,scrollY:10,addEventListener(){}};window.self=window.top=window;
 const document={hidden:false,body:{appendChild(el){if(el.isFrame)frames.push(el)},replaceChildren(){cleared++}},querySelector(){return {value:'csrf'}},addEventListener(){},createElement(tag){return {isFrame:tag==='iframe',style:{},setAttribute(){},remove(){removed++},contentDocument:{readyState:'complete',querySelector(){return valid?{}:null}},contentWindow:{location,scrollY:0,scrollTo(){},requestAnimationFrame(fn){fn()}}}}};
 vm.runInNewContext(source,{document,window,location,URL,AbortController,setTimeout(){return 1},clearTimeout(){},setInterval(fn,ms){timers.push({fn,ms})},fetch:async()=>({status:++calls===3?finalStatus:204})});
 await new Promise(setImmediate);
 await timers.find(x=>x.ms===300000).fn();
 assert.equal(frames.length,1);await frames[0].onload();
 if(!valid){assert.equal(removed,1);assert.equal(frames[0].style.opacity,'0');}
 else if(finalStatus===204)assert.equal(frames[0].style.opacity,'1');
 else {assert.equal(removed,1);assert.equal(frames[0].style.opacity,'0');}
 assert.equal(cleared,finalStatus===403?1:0);
}
(async()=>{
 await check(false,204);console.log('PASS failed/invalid iframe retains last valid dashboard');
 await check(true,503);console.log('PASS transient authorization failure never reveals new data');
 await check(true,403);console.log('PASS revocation during refresh hides existing data and rejects new frame');
 await check(true,204);console.log('PASS valid refreshed dashboard revealed only after authorization');
})().catch(e=>{console.error(e);process.exitCode=1});
