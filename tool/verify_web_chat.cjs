// Prueba opcional de navegador con Node 22+ y Chrome; sin paquetes adicionales.
// Sirve build/web, usa un perfil aislado y prueba el selector mediante CDP.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {spawn} = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve('build/web');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const server = http.createServer((req, res) => {
  const file = path.resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
  if (!file.startsWith(root + path.sep) && file !== root) { res.writeHead(403).end(); return; }
  const target = file === root ? path.join(root, 'index.html') : file;
  const mime = {'.js':'text/javascript','.html':'text/html','.wasm':'application/wasm','.json':'application/json','.png':'image/png'};
  res.setHeader('Content-Type', mime[path.extname(target)] || 'application/octet-stream');
  fs.createReadStream(target).on('error', () => res.writeHead(404).end()).pipe(res);
});
let chrome, ws, sequence = 0;
let fixture, chooserTask;
const pending = new Map();
async function send(method, params = {}) {
  const id = ++sequence;
  const result = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error('Timeout: ' + method)); }, 15000);
    pending.set(id, {resolve, reject, timeout});
  });
  ws.send(JSON.stringify({id, method, params})); return result;
}
async function evaluate(expression) {
  const result = await send('Runtime.evaluate', {expression, returnByValue:true});
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function click(label) {
  const point = await evaluate(`(() => {
    const nodes = [...document.querySelectorAll('[role="button"],[role="menuitem"]')];
    const node = nodes.find(n => (n.getAttribute('aria-label') === ${JSON.stringify(label)} || n.textContent.split('\\n')[0] === ${JSON.stringify(label)}) && n.getBoundingClientRect().width > 0);
    if (!node) return null; const r = node.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2};
  })()`);
  assert(point, 'Control no encontrado: ' + label);
  await send('Input.dispatchMouseEvent', {type:'mousePressed',button:'left',clickCount:1,...point});
  await send('Input.dispatchMouseEvent', {type:'mouseReleased',button:'left',clickCount:1,...point});
  await delay(400);
}
async function waitText(value) {
  for (let i=0;i<60;i++) {
    if (await evaluate(`document.body.textContent.includes(${JSON.stringify(value)}) || [...document.querySelectorAll('[aria-label],[aria-valuetext],input,textarea')].some(n => (n.getAttribute('aria-label') || n.getAttribute('aria-valuetext') || n.value || '').includes(${JSON.stringify(value)}))`)) return;
    await delay(200);
  }
  const shot = await send('Page.captureScreenshot'); fs.writeFileSync('build/web-chat-check.png', Buffer.from(shot.data, 'base64'));
  throw new Error('Texto no encontrado: ' + value);
}
(async () => {
  await new Promise(resolve => server.listen(8357, '127.0.0.1', resolve));
  chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new','--remote-debugging-port=9229','--window-size=1200,900',
    '--user-data-dir=' + path.resolve('build/web-chat-chrome-profile'),
    '--no-first-run','--no-default-browser-check','about:blank'
  ], {windowsHide:true, stdio:'ignore'});
  let target;
  for (let i=0;i<60;i++) {
    try { target = await (await fetch('http://127.0.0.1:9229/json/new?http://127.0.0.1:8357', {method:'PUT'})).json(); break; } catch { await delay(200); }
  }
  assert(target, 'Chrome no inició');
  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise(resolve => ws.addEventListener('open', resolve, {once:true}));
  ws.addEventListener('message', event => {
    const data = JSON.parse(event.data), item = pending.get(data.id);
    if (data.method === 'Page.fileChooserOpened') {
      chooserTask = send('DOM.setFileInputFiles', {backendNodeId:data.params.backendNodeId,files:[fixture]});
    }
    if (!item) return; clearTimeout(item.timeout); pending.delete(data.id);
    data.error ? item.reject(new Error(JSON.stringify(data.error))) : item.resolve(data.result);
  });
  await send('Runtime.enable'); await send('Page.enable'); await send('Network.enable'); await send('DOM.enable');
  for (let i=0;i<100;i++) {
    if (await evaluate(`!!document.querySelector('flt-semantics-placeholder')`)) break;
    await delay(200);
  }
  await evaluate(`document.querySelector('flt-semantics-placeholder')?.click()`);
  await waitText('ConectaLab'); await waitText('Chat');
  await click('Chat'); await waitText('Chat local');
  await send('Network.emulateNetworkConditions', {offline:true,latency:0,downloadThroughput:0,uploadThroughput:0});
  // El texto se introduce con eventos reales del navegador.
  const inputPoint = await evaluate(`(() => {const n=document.querySelector('flt-semantics[role="textbox"]') || document.querySelector('textarea,input:not([type=file])'); if(!n)return null;const r=n.getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);
  assert(inputPoint, 'Campo de mensaje disponible');
  await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...inputPoint});
  await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...inputPoint});
  await delay(300);
  await send('Input.insertText',{text:'Prueba local sin Internet en Chrome'});
  await delay(200);
  assert(await evaluate(`[...document.querySelectorAll('textarea')].some(n=>n.value==='Prueba local sin Internet en Chrome')`), 'Texto introducido en el compositor');
  await click('Añadir mensaje local'); await waitText('Tú · este dispositivo');
  fixture = path.resolve('build/web-chat-fixture.png');
  fs.writeFileSync(fixture, Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64'));
  await send('Page.setInterceptFileChooserDialog', {enabled:true});
  await click('Adjuntar imagen'); await click('Seleccionar imagen');
  if (chooserTask) {
    await chooserTask;
  } else {
  let inputId;
  for(let i=0;i<30;i++) {
    const doc = await send('DOM.getDocument',{depth:-1,pierce:true});
    function fileNode(node) {
      const attrs = node.attributes || [];
      if(node.nodeName === 'INPUT' && attrs.some((a,j)=>a==='type' && attrs[j+1]==='file')) return node.nodeId;
      for(const child of [...(node.children||[]),...(node.shadowRoots||[])]) { const found=fileNode(child); if(found)return found; }
    }
    inputId = fileNode(doc.root);
    if(inputId)break; await delay(200);
  }
  if (!inputId) { console.log(await evaluate(`document.body.textContent.slice(-2200)`)); const shot=await send('Page.captureScreenshot'); fs.writeFileSync('build/web-chat-check.png', Buffer.from(shot.data,'base64')); }
  assert(inputId, 'Selector nativo de archivos del navegador creado');
  await send('DOM.setFileInputFiles',{nodeId:inputId,files:[fixture]});
  }
  await waitText('Vista previa'); await click('Confirmar imagen');
  await waitText('Imagen adjunta:');
  await click('Inicio'); await click('Chat'); await waitText('Tú · este dispositivo');
  await click('Usuarios'); await waitText('API: no se pudo actualizar');
  await send('Network.emulateNetworkConditions', {offline:false,latency:0,downloadThroughput:-1,uploadThroughput:-1});
  await click('Actualizar usuarios'); await delay(2000);
  await click('Chat'); await click('Usuarios'); await waitText('30 perfiles');
  await send('Network.emulateNetworkConditions', {offline:true,latency:0,downloadThroughput:0,uploadThroughput:0});
  await click('Actualizar usuarios'); await delay(2000);
  await click('Chat'); await click('Usuarios'); await waitText('API: no se pudo actualizar');
  await waitText('Datos anteriores guardados en esta sesión');
  const shot = await send('Page.captureScreenshot'); fs.writeFileSync('build/web-chat-check.png', Buffer.from(shot.data, 'base64'));
  console.log('PASS: Chrome, chat e imágenes offline; API DummyJSON real, reintento online y error offline con datos anteriores identificados.');
})().catch(error => { console.error(error.message); process.exitCode=1; }).finally(async () => {
  if(ws?.readyState === WebSocket.OPEN) ws.close();
  chrome?.kill(); server.closeAllConnections(); server.close();
});
