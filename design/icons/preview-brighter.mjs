/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// Optical-weight study only: exported ICOs and installed binaries stay untouched.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { stackedBook } from './stacked-books.mjs';
import { smallIcon } from './small-icons.mjs';

const dir=path.dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json'),'utf8'));
const cases=[{label:'7-ZIP',color:'#a654ad',source:'app/app',variant:'app'},...['7z','zip','rar','iso'].map(name=>({...manifest.formats.find(e=>e.name===name),variant:'archive'}))];
const render=(svg,size)=>new Resvg(svg,{fitTo:{mode:'width',value:size},font:{loadSystemFonts:false,fontFiles:['C:/Windows/Fonts/segoeui.ttf']}}).render();
const oldIcon=(e,size)=>render(size<=32?smallIcon(e.label,e.color,e.variant,size,null,false,false):stackedBook(e.label,e.color,e.variant,null,false,false),size);
const newIcon=(e,size)=>render(size<=32?smallIcon(e.label,e.color,e.variant,size,null,false,true):stackedBook(e.label,e.color,e.variant,null,false,true),size);
const embed=(im,x,y)=>`<image x="${x}" y="${y}" width="${im.width}" height="${im.height}" href="data:image/png;base64,${im.asPng().toString('base64')}"/>`;
const text=(s,x,y,size=14,color='#28363f')=>`<text x="${x}" y="${y}" font-family="Segoe UI" font-size="${size}" fill="${color}">${s}</text>`;
let b='<rect width="890" height="640" fill="#f5f2eb"/>'+text('LESS PADDING / BRIGHTER COLORS',28,40,25);
cases.forEach((e,i)=>{
  const x=150+i*144;
  b+=text(e.label,x,78,16)+embed(oldIcon(e,96),x,94)+embed(newIcon(e,96),x,220);
});
b+=text('PREVIOUS',28,143)+text('CURRENT',28,268);
b+='<rect x="20" y="342" width="850" height="279" rx="12" fill="#272e39"/>';
b+=text('ACTUAL SIZE · EACH PAIR: PREVIOUS / CURRENT',38,373,14,'#e4ebef');
[16,20,24,32].forEach((size,row)=>{
  const y=387+row*52;
  b+=text(`${size} px`,38,y+27,13,'#abb8c4');
  cases.forEach((e,i)=>{b+=embed(oldIcon(e,size),150+i*144,y+34-size)+embed(newIcon(e,size),204+i*144,y+34-size);});
});
fs.writeFileSync(path.join(dir,'preview-books-brighter.png'),render(`<svg xmlns="http://www.w3.org/2000/svg" width="890" height="640">${b}</svg>`,890).asPng());
function coverage(im) {
  let x0=im.width,y0=im.height,x1=-1,y1=-1,count=0;
  const pixels=im.pixels;
  for(let y=0;y<im.height;y++)for(let x=0;x<im.width;x++)if(pixels[(y*im.width+x)*4+3]>=128){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);count++;}
  return {width:x1-x0+1,height:y1-y0+1,pixels:count};
}
console.log(JSON.stringify({previous16:coverage(oldIcon(cases[0],16)),current16:coverage(newIcon(cases[0],16))}));
