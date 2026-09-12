const test = require('node:test');
const assert = require('node:assert/strict');
require('../../web/maps/route_geometry.js');
const {issue, prepare} = globalThis.AonRouteGeometry;
const o = {lat:-33.7737,lng:151.1134}, d = {lat:-33.7746267,lng:151.1151193};
const points = [[-33.77373,151.1134],[-33.77372,151.11406],[-33.77430,151.11407],[-33.77438,151.11417],[-33.77441,151.11418],[-33.77438,151.11511]].map(([lat,lng])=>({lat,lng}));
test('rejects nonfinite, missing, wrong schema, swapped and out-of-range geometry',()=> {
  for (const p of [null,undefined,{}, {latitude:-33,longitude:151},
    ...[NaN,Infinity,-Infinity,null,undefined,'1'].flatMap(v=>[{lat:v,lng:151},{lat:-33,lng:v}]),
    {lat:91,lng:151},{lat:-91,lng:151},{lat:-33,lng:181},{lat:-33,lng:-181},
    {lat:151,lng:-33},{lat:0,lng:0}]) {
    assert.ok(issue(p));
    const g = prepare(o,d,[...points,p]);
    assert.deepEqual(g.points,[]);
    assert.deepEqual(g.boundsPoints,[o,d]);
  }
});
test('valid six-point route includes both endpoints and has campus-scale bounds',()=> {
  const g = prepare(o,d,points);
  assert.deepEqual(g.points,points);
  assert.deepEqual(g.boundsPoints,[o,d,...points]);
  assert.ok(Math.abs(g.bounds.latSpan - .0009267) < 1e-10);
  assert.ok(Math.abs(g.bounds.lngSpan - .0017193) < 1e-10);
});
test('valid numeric but distant contamination cannot expand campus bounds',()=> {
  for (const p of [{lat:0,lng:1},{lat:33.77,lng:151.11},{lat:40,lng:-74}]) {
    const logs=[]; const g=prepare(o,d,[...points,p],m=>logs.push(m));
    assert.ok(logs.includes('INVALID_ROUTE_BOUNDS'));
    assert.deepEqual(g.boundsPoints,[o,d]);
  }
});
test('old web decoder six-point corruption is rejected before Google Maps',()=> {
  const bad=[42915.89923,42915.89924,85865.57162,128815.2445,171764.91743,171764.91746].map((lat,i)=>({lat,lng:points[i].lng}));
  assert.deepEqual(prepare(o,d,bad).boundsPoints,[o,d]);
});
test('empty route falls back to endpoints; invalid endpoints never enter bounds',()=> {
  assert.deepEqual(prepare(o,d,[]).boundsPoints,[o,d]);
  assert.deepEqual(prepare(null,undefined,points).boundsPoints,[]);
});
test('envelope is geographic and also works outside Sydney',()=> {
  const a={lat:51.5,lng:-.1},b={lat:51.501,lng:-.101};
  assert.equal(prepare(a,b,[a,b]).points.length,2);
  assert.equal(prepare(a,b,points).points.length,0);
});
test('iframe applies only validated coordinates to native Maps constructors',()=> {
  const vm=require('node:vm'), fs=require('node:fs');
  const fitted=[], paths=[], markers=[];
  let onMessage;
  const maps={
    Map: class {addListener() {} fitBounds(b) {fitted.push(b.points)} getZoom(){return 18}},
    Marker: class {setPosition(p){assert.equal(issue(p),null);markers.push(p)} setMap(){}},
    Polyline: class {constructor(options){paths.push(options.path)} setMap(){}},
    LatLngBounds: class {constructor(){this.points=[]} extend(p){assert.equal(issue(p),null);this.points.push(p)}},
    event: {addListenerOnce(){}}
  };
  const window={location:{origin:'https://example.test'},google:{maps},addEventListener:(name,fn)=>onMessage=fn};
  const context={window,google:{maps},parent:{postMessage(){}},console:{log(){}},
    document:{getElementById(){return {}}},AonRouteGeometry:globalThis.AonRouteGeometry};
  vm.createContext(context);
  const page=fs.readFileSync('web/maps/directions_map.html','utf8');
  vm.runInContext(page.match(/<script>\s*([\s\S]*?)<\/script>/)[1],context);
  const send=data=>onMessage({origin:window.location.origin,data:{source:'aon-host',...data}});
  send({type:'init'});
  send({type:'setRoute',origin:o,destination:d,polyline:points});
  assert.deepEqual(paths[0],points);
  assert.deepEqual(fitted[0],[o,d,...points]);
  for(const bad of [{lat:42915.89923,lng:151},null,{lat:0,lng:0},{lat:50,lng:50}]) {
    send({type:'setRoute',origin:o,destination:d,polyline:[...points,bad]});
    assert.deepEqual(fitted.at(-1),[o,d]);
    assert.equal(paths.length,1); // No corrupt native Polyline was constructed.
  }
  assert.ok(markers.length>0);
});
