/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// Standalone design preview. Does not overwrite installed or exported resources.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { stackedBook } from './stacked-books.mjs';
import { smallIcon } from './small-icons.mjs';

const dir=path.dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json'),'utf8'));
const fontFile=process.env.ICON_SMALL_FONT || 'C:/Windows/Fonts/seguisb.ttf';
const app={label:'7-ZIP',color:'#a654ad',variant:'app',source:'app/app'};
const cases=[app,...['7z','zip','rar','iso'].map(name=>({...manifest.formats.find(e=>e.name===name),variant:'archive'}))];
const render=(svg,size)=>new Resvg(svg,{fitTo:{mode:'width',value:size},font:{fontFiles:[fontFile]}}).render();
const withoutLabel=(e,size)=>render(size<=32?smallIcon(e.label,e.color,e.variant,size,fontFile,false,manifest.vivid):stackedBook(e.label,e.color,e.variant,fontFile,false,manifest.vivid),size);
const embed=(im,x,y)=>`<image x="${x}" y="${y}" width="${im.width}" height="${im.height}" href="data:image/png;base64,${im.asPng().toString('base64')}"/>`;
const text=(s,x,y,size=15,fill='#28363f')=>`<text x="${x}" y="${y}" font-family="Segoe UI" font-size="${size}" fill="${fill}">${s}</text>`;
let b='<rect width="920" height="700" fill="#f5f2eb"/>';
b+=text('BOUND BOOKS / NO TEXT',28,40,25);
for(const [i,e] of cases.entries()) {
  const x=150+i*150;
  b+=text(e.label,x,76,16);
  b+=embed(render(stackedBook(e.label,e.color,e.variant,fontFile,true,manifest.vivid),96),x,91);
  b+=embed(withoutLabel(e,96),x,220);
}
b+=text('WITH TEXT',28,145,14)+text('NO TEXT',28,276,14);
b+='<rect x="20" y="337" width="880" height="265" rx="12" fill="#272e39"/>';
b+=text('ACTUAL SIZES',38,369,15,'#e3e9ef');
[16,24,32,48].forEach((size,row)=>{
  const y=386+row*52;
  b+=text(`${size} px`,38,y+22,13,'#abb8c4');
  cases.forEach((e,i)=>{b+=embed(withoutLabel(e,size),174+i*150,y+31-size);});
});
b+=text('INSTALL',38,655,13)+text('UNINSTALL',310,655,13)+text('SELF-EXTRACTING',585,655,13);
['install','uninstall','sfx'].forEach((variant,i)=>{b+=embed(withoutLabel({...app,variant},64),165+i*272,619);});
fs.writeFileSync(path.join(dir,'preview-books-no-text.png'),render(`<svg xmlns="http://www.w3.org/2000/svg" width="920" height="700">${b}</svg>`,920).asPng());
// Full archive atlas for the color-only variants.
let atlas='<rect width="1080" height="780" fill="#f5f2eb"/>'+text('34 FORMATS / NO TEXT',24,40,24);
manifest.formats.forEach((e,i)=>{
  const x=24+(i%8)*132,y=68+Math.floor(i/8)*138;
  atlas+=embed(withoutLabel({...e,variant:'archive'},80),x+12,y);
  atlas+=text('.'+e.name,x+12,y+108,14);
});
fs.writeFileSync(path.join(dir,'preview-books-no-text-all.png'),render(`<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="780">${atlas}</svg>`,1080).asPng());
console.log('Created unlabeled comparison and full-format previews; existing exported resources unchanged.');
