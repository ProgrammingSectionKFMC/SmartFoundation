using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.Extensions.Logging.Abstractions;
using SmartFoundation.Application.Services;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.Mvc.Controllers.Housing;
using SmartFoundation.Mvc.Services.DataLoad;
using SmartFoundation.UI.ViewModels.SmartPage;

void Check(bool ok, string name) { if (!ok) throw new Exception(name); Console.WriteLine("PASS " + name); }
async Task<(IActionResult Result, FakeEngine Engine, HousingController Controller)> Load(int? year, int? month, long? idara, bool permission=true, bool retry=true, bool rows=true, bool invalidModel=false) {
 var engine = new FakeEngine(permission,retry,rows);
 var masters = new MastersServies(engine,NullLogger<MastersServies>.Instance);
 var http = new DefaultHttpContext { Session = new FakeSession() };
 http.Session.SetString("usersID","7"); http.Session.SetString("IdaraID","3");
 http.Request.Path="/Housing/MonthlyBillingMonitor";
 http.Request.QueryString=year.HasValue?new QueryString($"?year={year}&month={month}&idaraID={idara}"):QueryString.Empty;
 var controller = new HousingController(masters,null!,null!) { ControllerContext = new ControllerContext { HttpContext=http },TempData=new TempDataDictionary(http,new FakeTempData()) };
 if(invalidModel)controller.ModelState.AddModelError("year","Invalid binding");
 var loader = new RequestScopedDataLoadService(masters,new HttpContextAccessor { HttpContext=http });
 return (await controller.MonthlyBillingMonitor(loader,year,month,idara),engine,controller);
}
SmartPageViewModel Page(IActionResult result)=>(SmartPageViewModel)((ViewResult)result).Model!;
var initial=await Load(null,null,null);var initialPage=Page(initial.Result);
Check(initialPage.TableDS==null && initialPage.TableDS2==null,"initial visit displays filter only despite available data");
var button=initialPage.Form!.Fields.Single(f=>f.InlineButton);
File.WriteAllText(".backups/monthly-billing-checks/filter.json", System.Text.Json.JsonSerializer.Serialize(button));
Check(button.InlineButtonOnClickJs=="sfNav(this)" && button.InlineButtonCss=="btn btn-success" && button.NavField3=="month" && button.NavField4=="idaraID","HousingExit inline button and dynamic filter navigation");
var filtered=await Load(2026,10,3);var page=Page(filtered.Result);
Check(page.TableDS?.Rows.Count==1 && page.TableDS2?.Rows.Count==1,"valid submitted filter displays both result tables");
Check(Convert.ToInt32(filtered.Engine.Last!.Params["parameter_01"])==2026 && Convert.ToInt32(filtered.Engine.Last.Params["parameter_02"])==10 && Convert.ToInt64(filtered.Engine.Last.Params["parameter_03"])==3,"SQL positional parameters preserved");
Check(page.TableDS!.Toolbar!.ShowEdit && Convert.ToInt32(page.TableDS.Rows[0]["p01"])==11,"retry permission and selected run alias preserved");
var form=page.TableDS.Toolbar.Edit!.OpenForm!;
Check(form.ActionUrl=="/crud/update" && form.Fields.Any(f=>f.Name=="ActionType" && f.Value=="RETRYMONTHLYBILLING") && form.Fields.Any(f=>f.Name=="redirectUrl" && f.Value!.Contains("year=2026")),"retry CRUD contract and filter return URL preserved");
var all=await Load(2026,10,0);
Check(!all.Engine.Last!.Params.ContainsKey("parameter_03"),"all-departments sentinel is never forwarded to SQL");
Check(Page((await Load(2026,13,3)).Result).TableDS==null,"invalid month hides results");
Check(Page((await Load(0,10,3)).Result).TableDS==null,"invalid year hides results");
Check(Page((await Load(2026,10,-1)).Result).TableDS==null,"invalid department hides results");
Check(Page((await Load(null,10,null)).Result).TableDS==null,"partial filter hides results");
Check(Page((await Load(2026,10,3,invalidModel:true)).Result).TableDS==null,"binding errors hide results");
Check(!Page((await Load(2026,10,3,retry:false)).Result).TableDS!.Toolbar!.ShowEdit,"retry unavailable without permission");
Check((await Load(2026,10,3,permission:false)).Result is RedirectToActionResult,"missing page permission redirects");
var empty=await Load(2026,10,3,rows:false);
Check(Page(empty.Result).TableDS==null && Page(empty.Result).TableDS2==null && empty.Controller.TempData.ContainsKey("Info"),"empty results show feedback without empty action tables");

sealed class FakeEngine(bool permission,bool retry,bool rows):ISmartComponentService {
 public SmartRequest? Last;
 public Task<SmartResponse> ExecuteAsync(SmartRequest request,CancellationToken ct=default) {
 Last=request;
 var permissions=new List<Dictionary<string,object?>>();
 if(permission)permissions.Add(new(){["permissionTypeName_E"]=retry?"RETRYMONTHLYBILLING":"VIEW"});
 var runs=new List<Dictionary<string,object?>>();var details=new List<Dictionary<string,object?>>();
 if(rows){runs.Add(new(){["MonthlyBillingRunID"]=11,["PeriodYear"]=2026,["PeriodMonth"]=10,["IdaraID_FK"]=3});details.Add(new(){["MonthlyBillingRunDetailsID"]=12});}
 return Task.FromResult(new SmartResponse {Success=true,Datasets=new(){permissions,runs,details,new(){new(){["idaraID"]=3,["idaraLongName_A"]="Test"}}},DatasetSchemas=new(){new(){"permissionTypeName_E"},new(){"MonthlyBillingRunID","PeriodYear","PeriodMonth","IdaraID_FK"},new(){"MonthlyBillingRunDetailsID"},new(){"idaraID","idaraLongName_A"}}});
 }
}
sealed class FakeSession:ISession {
 readonly Dictionary<string,byte[]> values=new(); public bool IsAvailable=>true;public string Id=>"test";public IEnumerable<string> Keys=>values.Keys;
 public void Clear()=>values.Clear();public void Remove(string key)=>values.Remove(key);public void Set(string key,byte[] value)=>values[key]=value;public bool TryGetValue(string key,out byte[]? value)=>values.TryGetValue(key,out value);
 public Task LoadAsync(CancellationToken cancellationToken=default)=>Task.CompletedTask;public Task CommitAsync(CancellationToken cancellationToken=default)=>Task.CompletedTask;
}
sealed class FakeTempData:ITempDataProvider {
 public IDictionary<string,object> LoadTempData(HttpContext context)=>new Dictionary<string,object>();public void SaveTempData(HttpContext context,IDictionary<string,object> values){}
}
