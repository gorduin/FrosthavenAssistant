// The phone companion page served by PhoneServer (plain HTML/JS, made for
// iPhone Safari; no install, no external resources).

const String phoneLockedHtml = r'''<!doctype html>
<html lang="hu"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>X-haven</title>
<style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
background:#0a1018;color:#e9f1f7;font:18px -apple-system,system-ui,sans-serif;text-align:center;padding:24px;box-sizing:border-box}
b{color:#4ff2ff}</style></head>
<body><div><h2>X-haven</h2><p>Szkenneld be a <b>QR-kódot</b> a tévéről<br>(Beállítások → Telefonok).</p>
<p style="opacity:.6">Scan the QR code shown on the TV.</p></div></body></html>
''';

const String phonePageHtml = r'''<!doctype html>
<html lang="hu"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="theme-color" content="#0a1018">
<title>X-haven</title>
<style>
:root{--bg:#0a1018;--panel:#121b26;--panel2:#182431;--line:rgba(190,215,235,.14);--fg:#e9f1f7;
--muted:rgba(233,241,247,.6);--focus:#4ff2ff;--hp:#e04e4e;--xp:#9fd6ff;--ok:#8bd17c;--elite:#f1c40f}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;background:var(--bg);color:var(--fg);font:16px -apple-system,system-ui,sans-serif}
body{padding:calc(env(safe-area-inset-top) + 8px) 14px calc(env(safe-area-inset-bottom) + 20px)}
button{font:inherit;color:inherit;border:1px solid var(--line);background:var(--panel2);border-radius:14px;
touch-action:manipulation;cursor:pointer}
button:active{transform:scale(.97);background:#22374a}
.top{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-bottom:10px}
.top h1{font-size:20px;margin:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.top .r{color:var(--muted);font-size:14px;white-space:nowrap}
.status{position:fixed;left:0;right:0;top:0;padding:calc(env(safe-area-inset-top) + 6px) 12px 6px;
background:#7a2b2b;color:#fff;text-align:center;font-size:14px;display:none;z-index:9}
.phase{display:inline-block;padding:3px 10px;border-radius:9px;background:var(--panel2);border:1px solid var(--line);
font-size:13px;color:var(--focus)}
.card{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:16px;margin-bottom:12px}
.pick{display:flex;align-items:center;gap:14px;width:100%;padding:12px;margin-bottom:10px;text-align:left}
.av{width:52px;height:52px;border-radius:50%;background:#0b141d;border:2px solid var(--line);display:flex;
align-items:center;justify-content:center;flex:none}
.av img{width:38px;height:38px;object-fit:contain}
.mask{display:inline-block;-webkit-mask-repeat:no-repeat;mask-repeat:no-repeat;-webkit-mask-position:center;
mask-position:center;-webkit-mask-size:contain;mask-size:contain}
.av .mask{width:38px;height:38px}
.tbl .mask{width:30px;height:30px}
.who{display:flex;align-items:center;gap:14px;margin-bottom:6px}
.who .n{font-size:22px;font-weight:700}
.who .s{color:var(--muted);font-size:14px}
.big{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:14px 0 6px}
.big .val{font-size:52px;font-weight:800;text-align:center;flex:1;line-height:1}
.big .val small{font-size:20px;color:var(--muted);font-weight:500}
.big button{width:78px;height:78px;font-size:38px;font-weight:700;border-radius:20px}
.minus{background:#3a1c22}.plus{background:#17331f}
.bar{height:10px;border-radius:5px;background:rgba(224,78,78,.18);overflow:hidden}
.bar i{display:block;height:100%;background:linear-gradient(90deg,#ff6b6b,var(--hp))}
.lbl{font-size:12px;letter-spacing:.16em;text-transform:uppercase;color:var(--muted);margin:2px 0 8px}
.row{display:flex;gap:10px;align-items:center}
.row .grow{flex:1}
.small{display:flex;align-items:center;gap:10px}
.small button{width:52px;height:52px;font-size:26px}
.small .v{min-width:56px;text-align:center;font-size:26px;font-weight:700;color:var(--xp)}
.init input{width:100%;height:60px;font-size:30px;text-align:center;border-radius:14px;border:2px solid var(--focus);
background:#0b141d;color:var(--fg)}
.init .cur{font-size:44px;font-weight:800;text-align:center}
.primary{background:var(--focus);color:#06202a;border-color:transparent;font-weight:700;height:60px;width:100%;font-size:19px}
.conds{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}
.cond{padding:8px 4px;display:flex;flex-direction:column;align-items:center;gap:4px;font-size:11px;color:var(--muted);
opacity:.55}
.cond img{width:34px;height:34px}
.cond.on{opacity:1;border-color:var(--focus);background:#1e3a50;color:var(--fg)}
.sum{display:flex;align-items:center;gap:10px;padding:8px 0;border-top:1px solid var(--line)}
.sum .nm{flex:1}
.sum button{width:46px;height:46px;font-size:24px}
.sum .hpv{min-width:64px;text-align:center;font-weight:700}
.tbl .it{display:flex;align-items:center;gap:10px;padding:8px 0;border-top:1px solid var(--line)}
.tbl .it:first-child{border-top:0}
.tbl .ini{width:34px;text-align:center;font-weight:800;color:var(--muted)}
.tbl .it.cur .ini{color:var(--focus)}
.tbl .it.done{opacity:.45}
.tbl .nm{flex:1}
.tbl .hp{color:var(--muted);font-size:14px}
.tbl img{width:30px;height:30px;border-radius:50%;object-fit:cover}
.link{background:none;border:0;color:var(--focus);padding:12px;width:100%;font-size:15px}
.done-badge{color:var(--ok);text-align:center;font-weight:700;padding:10px}
</style></head>
<body>
<div class="status" id="status"></div>
<div id="app"></div>
<script>
(function(){
"use strict";
var key=new URLSearchParams(location.search).get("k")||"";
var S=null, ws=null, mine=localStorage.getItem("xh_char")||"", pendingInit="";
var T={
 hu:{pick:"Válaszd ki a karaktered",round:"kör",init:"Kezdeményezés",play:"Körök folynak",hp:"Életerő",xp:"Tapasztalat",
  ini:"Kezdeményezés",save:"Mentés",turnDone:"Köröm kész",turnIsDone:"A köröd kész",conds:"Állapotok",summons:"Idézések",
  table:"Asztal",change:"Karakter váltása",lost:"Kapcsolat megszakadt, újracsatlakozás…",noChar:"Még nincs karakter a játékban.",
  level:"szint",yourTurn:"Te jössz!",wait:"Várakozás a húzásra"},
 en:{pick:"Choose your character",round:"round",init:"Choose initiative",play:"Playing turns",hp:"Health",xp:"Experience",
  ini:"Initiative",save:"Save",turnDone:"My turn is done",turnIsDone:"Your turn is done",conds:"Conditions",summons:"Summons",
  table:"Table",change:"Change character",lost:"Connection lost, reconnecting…",noChar:"No characters in the game yet.",
  level:"level",yourTurn:"Your turn!",wait:"Waiting for the draw"}
};
function t(k){return (T[S&&S.lang]||T.hu)[k]||k}
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]})}
function img(p){return "/"+p.split("/").map(encodeURIComponent).join("/")}
function send(o){if(ws&&ws.readyState===1)ws.send(JSON.stringify(o))}

function connect(){
 ws=new WebSocket("ws://"+location.host+"/ws?k="+encodeURIComponent(key));
 ws.onopen=function(){status("")};
 ws.onmessage=function(e){var m=JSON.parse(e.data); if(m.type==="state"){S=m;render()}};
 ws.onclose=function(){status(t("lost"));setTimeout(connect,2000)};
}
function status(s){var el=document.getElementById("status");el.textContent=s;el.style.display=s?"block":"none"}

function header(){
 return '<div class="top"><h1>'+esc(S.scenario||"X-haven")+'</h1><div class="r">'+S.round+'. '+t("round")+
 ' · <span class="phase">'+(S.phase==="play"?t("play"):t("init"))+'</span></div></div>';
}
function tinted(icon,color,cls){var u="url('"+img(icon).replace(/'/g,"%27")+"')";
 return '<span class="mask '+(cls||'')+'" style="background:'+color+';-webkit-mask-image:'+u+';mask-image:'+u+'"></span>'}
function av(c){return '<div class="av" style="border-color:'+c.color+'">'+(c.player?tinted(c.icon,c.color):'<img src="'+img(c.icon)+'">')+'</div>'}

function renderPick(){
 var players=S.characters.filter(function(c){return c.player});
 var h=header()+'<div class="lbl">'+t("pick")+'</div>';
 if(!players.length)h+='<div class="card">'+t("noChar")+'</div>';
 players.forEach(function(c){
  h+='<button class="pick" data-pick="'+esc(c.id)+'">'+av(c)+'<div><div style="font-size:19px;font-weight:700">'+
  esc(c.name)+'</div><div style="color:var(--muted);font-size:14px">'+esc(c.className)+' · '+c.level+'. '+t("level")+
  '</div></div></button>';
 });
 return h+table();
}

function renderMine(c){
 var pct=c.maxHp?Math.max(0,Math.min(100,c.hp*100/c.maxHp)):0;
 var h=header();
 h+='<div class="card"><div class="who">'+av(c)+'<div><div class="n">'+esc(c.name)+'</div><div class="s">'+
  esc(c.className)+' · '+c.level+'. '+t("level")+'</div></div></div>';
 if(S.phase==="play"&&c.turn==="current")h+='<div class="done-badge" style="color:var(--focus)">'+t("yourTurn")+'</div>';
 h+='<div class="lbl">'+t("hp")+'</div><div class="big"><button class="minus" data-hp="-1">−</button>'+
  '<div class="val">'+c.hp+'<small> / '+c.maxHp+'</small></div><button class="plus" data-hp="1">+</button></div>'+
  '<div class="bar"><i style="width:'+pct+'%"></i></div></div>';

 h+='<div class="card init"><div class="lbl">'+t("ini")+'</div>';
 if(S.phase==="init"){
  var v=pendingInit!==""?pendingInit:(c.init>0?c.init:"");
  h+='<div class="row"><input id="ini" class="grow" type="text" inputmode="numeric" pattern="[0-9]*" maxlength="2" value="'+v+
   '" placeholder="–"><button class="primary" style="width:120px" data-saveinit>'+t("save")+'</button></div>';
 }else{
  h+='<div class="cur">'+(c.init>0?c.init:"–")+'</div>';
  if(c.turn!=="done")h+='<button class="primary" data-turndone style="margin-top:10px">'+t("turnDone")+'</button>';
  else h+='<div class="done-badge">'+t("turnIsDone")+'</div>';
 }
 h+='</div>';

 h+='<div class="card"><div class="row"><div class="grow"><div class="lbl">'+t("xp")+'</div></div><div class="small">'+
  '<button class="minus" data-xp="-1">−</button><div class="v">'+c.xp+'</div><button class="plus" data-xp="1">+</button></div></div></div>';

 var on={};c.conditions.forEach(function(x){on[x.id]=1});
 h+='<div class="card"><div class="lbl">'+t("conds")+'</div><div class="conds">';
 c.available.forEach(function(x){
  h+='<button class="cond'+(on[x.id]?' on':'')+'" data-cond="'+x.id+'" data-on="'+(on[x.id]?0:1)+'"><img src="'+img(x.icon)+
   '"><span>'+esc(x.name)+'</span></button>';
 });
 h+='</div></div>';

 if(c.summons.length){
  h+='<div class="card"><div class="lbl">'+t("summons")+'</div>';
  c.summons.forEach(function(s){
   h+='<div class="sum"><div class="nm">'+esc(s.name)+(s.nr?' '+s.nr:'')+'</div><button class="minus" data-shp="-1" data-sid="'+
    esc(s.id)+'">−</button><div class="hpv">'+s.hp+' / '+s.maxHp+'</div><button class="plus" data-shp="1" data-sid="'+
    esc(s.id)+'">+</button></div>';
  });
  h+='</div>';
 }
 h+=table()+'<button class="link" data-change>'+t("change")+'</button>';
 return h;
}

function table(){
 var items=[];
 S.characters.forEach(function(c){items.push({ini:c.init>0?c.init:null,name:c.name,icon:c.icon,turn:c.turn,
  color:c.player?c.color:null,hp:c.hp+'/'+c.maxHp})});
 S.monsters.forEach(function(m){
  if(!m.standees.length)return;
  items.push({ini:m.init,name:m.name,icon:m.icon,turn:m.turn,hp:m.standees.map(function(s){return s.nr+': '+s.hp}).join(' · ')});
 });
 var h='<div class="card tbl"><div class="lbl">'+t("table")+'</div>';
 items.forEach(function(i){
  var cls=S.phase==="play"?(i.turn==="current"?" cur":(i.turn==="done"?" done":"")):"";
  h+='<div class="it'+cls+'"><div class="ini">'+(i.ini==null?'–':i.ini)+'</div>'+(i.color?tinted(i.icon,i.color):'<img src="'+img(i.icon)+'">')+'<div class="nm">'+
   esc(i.name)+'</div><div class="hp">'+esc(i.hp)+'</div></div>';
 });
 return h+'</div>';
}

function render(){
 if(!S)return;
 var focused=document.activeElement&&document.activeElement.id==="ini";
 if(focused)return; // do not rebuild while typing the initiative
 var c=S.characters.filter(function(x){return x.id===mine})[0];
 document.getElementById("app").innerHTML=c?renderMine(c):renderPick();
}

document.addEventListener("click",function(e){
 var b=e.target.closest("button");if(!b)return;
 var d=b.dataset;
 if(d.pick!==undefined){mine=d.pick;localStorage.setItem("xh_char",mine);render();return}
 if(d.change!==undefined){mine="";localStorage.removeItem("xh_char");render();return}
 if(d.hp)send({type:"hp",id:mine,owner:mine,delta:+d.hp});
 if(d.xp)send({type:"xp",id:mine,owner:mine,delta:+d.xp});
 if(d.shp)send({type:"hp",id:d.sid,owner:mine,delta:+d.shp});
 if(d.cond)send({type:"cond",id:mine,owner:mine,cond:d.cond,on:d.on==="1"});
 if(d.turndone!==undefined)send({type:"turnDone",id:mine,owner:mine});
 if(d.saveinit!==undefined){
  var el=document.getElementById("ini");var v=parseInt(el&&el.value,10);
  if(v>=1&&v<=99){send({type:"init",id:mine,owner:mine,value:v});pendingInit="";el.blur();setTimeout(render,50)}
 }
});
document.addEventListener("input",function(e){if(e.target.id==="ini")pendingInit=e.target.value.replace(/\D/g,"")});
document.addEventListener("keydown",function(e){
 if(e.target.id==="ini"&&e.key==="Enter"){var b=document.querySelector("[data-saveinit]");if(b)b.click()}
});
document.addEventListener("focusout",function(e){if(e.target.id==="ini")setTimeout(render,50)});
connect();
})();
</script>
</body></html>
''';
