/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// Native 16–32px book stacks: whole-pixel covers, quiet pages, real semibold text.
import { bookColors, mixColor, fittedLabel } from './stacked-books.mjs';

export function smallIcon(label,color,variant,size,fontFile,showLabel=true,vivid=false) {
  const short={LZMA:'LM',LZMA2:'L2',ZSTD:'ZS',CPIO:'CP',APFS:'AP',NTFS:'NT',SQFS:'SQ'};
  if(size===16) label=variant==='archive'?(short[label] || label):'7Z';
  const colors=bookColors(color,variant,vivid);
  let b='';
  const rect=(x,y,w,h,fill)=>{b+=`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"/>`;};
  const fuller=vivid&&!showLabel;
  const left=fuller?0:1,right=fuller?size:size-1,top=fuller?0:1,depth=size>=24?3:2;
  const rowHeight=showLabel?{16:3,20:4,24:5,32:7}[size]:Math.floor((size-2)/3);
  const rows=fuller?[0,Math.round((size-1)/3),Math.round(2*(size-1)/3),size-1]:[top,top+rowHeight,top+rowHeight*2,top+rowHeight*3];
  for(let i=2;i>=0;i--) {
    const y=rows[i],height=rows[i+1]-y,c=colors[i],front=right-depth;
    rect(left+1,y,right-left-1,height,mixColor(c,'#000000',vivid?.12:.18));
    rect(left,y+1,front-left,height-1,c);
    rect(left+1,y,front-left-1,1,mixColor(c,'#ffffff',.25));
    rect(front,y+1,depth,height-2,vivid?'#fff0ce':'#e4dcc5');
    if(size>=24)rect(left+2,y+2,1,height-3,vivid?'#f8dc9b':'#dec795');
  }
  const beltX=Math.round(size*.6),beltW=size>=24?4:3;
  rect(beltX,top,beltW,rows[3]-top,vivid?'#a67644':'#91603b');
  rect(beltX,top,1,rows[3]-top,vivid?'#e1b877':'#c0996a');
  const buckleY=rows[1],buckleH=size>=24?6:4;
  rect(beltX-1,buckleY,beltW+2,buckleH,vivid?'#f1f6f4':'#dce3e3');
  rect(beltX,buckleY+1,beltW,buckleH-2,'#765335');
  rect(beltX+1,buckleY+1,1,buckleH-2,'#edf1ee');
  if(showLabel) {
    const {box,text}=fittedLabel(label,{16:8,20:9,24:10,32:12}[size],size-2,fontFile);
    const plateW=Math.min(size,Math.ceil(box.width)+2),plateH=Math.ceil(box.height)+2,plateY=size-plateH;
    rect(0,plateY,plateW,plateH,'#bec2be');
    rect(0,plateY,plateW-1,plateH-1,'#fffdf7');
    b+=`<g fill="#28363f" transform="translate(${1-box.x} ${plateY+1-box.y})">${text}</g>`;
  }
  if(variant!=='archive'&&variant!=='app') {
    const r=size===16?3:4,c=size-r;
    b+=`<circle cx="${c}" cy="${c}" r="${r-.5}" fill="${variant==='uninstall'?'#b83a44':variant==='sfx'?'#19755e':'#176fb0'}" stroke="white" stroke-width="1"/>`;
    if(variant==='uninstall')b+=`<path d="m${c-1} ${c-1} 2 2m0-2-2 2" stroke="white"/>`;
    else if(variant==='sfx')b+=`<path d="M${c-1} ${c-1.5}l2.5 1.5-2.5 1.5Z" fill="white"/>`;
    else b+=`<path d="M${c} ${c-2}v4m-1.5-1.5 1.5 1.5 1.5-1.5" fill="none" stroke="white"/>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${b}</svg>`;
}
