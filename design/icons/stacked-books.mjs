/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// Original vector artwork inspired by the bound-book archive metaphor.
import { Resvg } from '@resvg/resvg-js';

export function mixColor(color,other,weight) {
  return '#'+[1,3,5].map(i=>Math.round(parseInt(color.slice(i,i+2),16)*(1-weight)+parseInt(other.slice(i,i+2),16)*weight).toString(16).padStart(2,'0')).join('');
}
export function brightenColor(color) {
  const rgb=[1,3,5].map(i=>parseInt(color.slice(i,i+2),16)/255);
  const high=Math.max(...rgb),low=Math.min(...rgb),delta=high-low;
  const v=Math.min(.98,high*1.13+.035),s=high?delta/high:0;
  const saturation=s>.18?s+.05*(1-s):s;
  return '#'+rgb.map(c=>Math.round(255*v*(1-saturation+saturation*(delta?(c-low)/delta:0))).toString(16).padStart(2,'0')).join('');
}
export function bookColors(color,variant,vivid=false) {
  if(vivid) return variant==='archive'
    ? [brightenColor(color),mixColor(brightenColor(color),'#2b9fdf',.84),mixColor(brightenColor(color),'#43be72',.88)]
    : ['#cb69db','#3cb5f1','#5ed17e'];
  return variant==='archive'
    ? [color,mixColor(color,'#347cb5',.76),mixColor(color,'#438b63',.8)]
    : ['#a654ad','#388dc1','#519669'];
}
export function fittedLabel(label,fontSize,maxWidth,fontFile) {
  const text=size=>`<text y="${size}" font-family="Segoe UI" font-weight="600" font-size="${size}">${label}</text>`;
  const measure=size=>new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="512" height="64">${text(size)}</svg>`,{font:{loadSystemFonts:false,fontFiles:[fontFile]}}).innerBBox();
  let box=measure(fontSize);
  fontSize*=Math.min(1,maxWidth/box.width);
  box=measure(fontSize);
  return {box,text:text(fontSize)};
}
export function stackedBook(label,color,variant,fontFile,showLabel=true,vivid=false) {
  const colors=bookColors(color,variant,vivid);
  let b=`<defs>
    <linearGradient id="leather"><stop stop-color="#ba8b58"/><stop offset=".22" stop-color="#986b40"/><stop offset=".8" stop-color="#80522f"/><stop offset="1" stop-color="#684128"/></linearGradient>
    <linearGradient id="buckle" x2=".8" y2="1"><stop stop-color="#ffffff"/><stop offset=".45" stop-color="#d7dee2"/><stop offset=".75" stop-color="#8c9a9f"/><stop offset="1" stop-color="#f3f6f5"/></linearGradient>
    <linearGradient id="paper"><stop stop-color="#f9f2da"/><stop offset="1" stop-color="#d6ccb0"/></linearGradient>`;
  colors.forEach((c,i)=>{b+=`<linearGradient id="spine${i}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${mixColor(c,'#ffffff',vivid?.24:.15)}"/><stop offset=".35" stop-color="${c}"/><stop offset="1" stop-color="${mixColor(c,'#000000',vivid?.15:.24)}"/></linearGradient>`;});
  b+='</defs>';
  if(vivid&&!showLabel)b+='<g transform="translate(-3.6 -3.6) scale(1.12)">';
  b+='<ellipse cx="32" cy="56" rx="27" ry="3" fill="#18242e" opacity=".12"/>';
  // Draw the bottom volume first. Each volume has a cover, rounded spine and pages.
  for(let i=2;i>=0;i--) {
    const y=7+i*14,c=colors[i];
    b+=`<path d="M7 ${y+6} 17 ${y}H58v11l-10 6H10q-4 0-4-4v-4q0-2 1-3Z" fill="${mixColor(c,'#000000',.35)}"/>
      <path d="M8 ${y+5} 17 ${y}H58l-10 6H8Z" fill="${mixColor(c,'#ffffff',.28)}"/>
      <path d="M48 ${y+7} 57 ${y+2}v8l-9 5Z" fill="url(#paper)"/>
      <path d="m49 ${y+9} 7-4m-7 6 7-4m-7 6 7-4" stroke="#948a72" stroke-opacity=".35" stroke-width=".55"/>
      <path d="M10 ${y+6}h38v10H10q-4 0-4-4v-2q0-4 4-4Z" fill="url(#spine${i})"/>
      <path d="M10 ${y+7}h37" stroke="#ffffff" stroke-opacity=".22" stroke-width=".6"/>
      <path d="M12 ${y+8}v6m3-6v6" stroke="#ead394" stroke-width="1.1" stroke-opacity=".8"/>
      <path d="m48 ${y+16} 10-6" stroke="${mixColor(c,'#000000',.2)}" stroke-width="1.2"/>`;
  }
  b+=`<path d="M34 13 44 7h8l-10 6Z" fill="#b88a55"/>
    <path d="M33.5 13h9v39h-9Z" fill="#17232c" opacity=".2"/>
    <path d="M34 13h8v38q-4 2-8 0Z" fill="url(#leather)"/>
    <path d="M35.4 14v35m5.2-35v35" stroke="#dec39a" stroke-width=".55" stroke-dasharray="1.5 1.5" opacity=".65"/>
    <rect x="32.7" y="29.7" width="11.6" height="12.4" rx="2" fill="#202a30" opacity=".3"/>
    <rect x="32" y="29" width="12" height="12" rx="2" fill="url(#buckle)"/>
    <rect x="34.7" y="31.5" width="6.6" height="7" rx=".7" fill="#785132"/>
    <path d="M38 31v8" stroke="#edf1ef" stroke-width="1.5" stroke-linecap="round"/>`;
  if(showLabel) {
    const {box,text}=fittedLabel(label,11.5,37,fontFile),width=box.width+7;
    b+=`<rect x="4.5" y="49.7" width="${width}" height="13" rx="2" fill="#19232c" opacity=".17"/>
    <rect x="4" y="49" width="${width}" height="13" rx="2" fill="#fffdf7" stroke="#b6bab5" stroke-width=".65"/>
    <g fill="#28363f" transform="translate(${7.5-box.x} ${49+(13-box.height)/2-box.y})">${text}</g>`;
  }
  if(vivid&&!showLabel)b+='</g>';
  if(variant!=='archive'&&variant!=='app') {
    const badge=variant==='uninstall'?'#c1454b':variant==='sfx'?'#24836b':'#267ec1';
    b+=`<circle cx="53" cy="53" r="10" fill="#fffdf7"/><circle cx="53" cy="53" r="8.5" fill="${badge}"/>`;
    if(variant==='uninstall') b+='<path d="m50 50 6 6m0-6-6 6" stroke="white" stroke-width="2" stroke-linecap="round"/>';
    else if(variant==='sfx') b+='<path d="m50.5 48.5 6.5 4.5-6.5 4.5Z" fill="white"/>';
    else b+='<path d="M53 48v9m-3.5-3.5L53 57l3.5-3.5" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>';
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">${b}</svg>`;
}
