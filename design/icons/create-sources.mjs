/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// Design geometry. Run explicitly to reset SVG masters; build.mjs preserves edits.
// Labels are outlined once so normal resource builds require no installed fonts.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { smallIcon } from './small-icons.mjs';
import { stackedBook } from './stacked-books.mjs';

const dir = path.dirname(fileURLToPath(import.meta.url));
const fontFile = process.env.ICON_FONT || 'C:/Windows/Fonts/segoeui.ttf';
const smallFontFile = process.env.ICON_SMALL_FONT || 'C:/Windows/Fonts/seguisb.ttf';
if (!fs.existsSync(fontFile)) throw new Error('Set ICON_FONT to a Segoe UI font file. Ordinary builds do not need it.');
if (!fs.existsSync(smallFontFile)) throw new Error('Set ICON_SMALL_FONT to Segoe UI Semibold. Ordinary builds do not need it.');
// Keep the original palette as the input so regeneration never lightens twice.
const baseFormats = [
  ['7z','7Z','#087bd9'], ['zip','ZIP','#b87808'], ['rar','RAR','#8253cd'],
  ['tar','TAR','#187f80'], ['gz','GZ','#27934e'], ['xz','XZ','#515bd1'],
  ['zst','ZST','#ce4c55'], ['zstd','ZSTD','#b93d56'], ['bz2','BZ2','#168b9c'],
  ['br','BR','#ae4a91'], ['lz4','LZ4','#2774b4'], ['lz5','LZ5','#4f68a8'],
  ['lzma','LZMA','#6f58b0'], ['lzma2','LZMA2','#9852b0'], ['liz','LIZ','#498042'],
  ['lzh','LZH','#9a713a'], ['lha','LHA','#a56845'], ['z','Z','#4b7e94'],
  ['arj','ARJ','#a85356'], ['cab','CAB','#a47728'], ['cpio','CPIO','#738333'],
  ['xar','XAR','#537562'], ['split','001','#737c8d'], ['deb','DEB','#b94363'],
  ['rpm','RPM','#b15639'], ['iso','ISO','#527b9b'], ['dmg','DMG','#6d76a5'],
  ['vhd','VHD','#326986'], ['wim','WIM','#267f9f'], ['apfs','APFS','#6074a0'],
  ['hfs','HFS','#8a6f94'], ['ntfs','NTFS','#526d80'], ['fat','FAT','#72835e'],
  ['sqfs','SQFS','#537b74']
];
function mix(color,other,weight) {
  return '#'+[1,3,5].map(i=>Math.round(parseInt(color.slice(i,i+2),16)*(1-weight)+parseInt(other.slice(i,i+2),16)*weight).toString(16).padStart(2,'0')).join('');
}
const overrides={'7z':'#419bcc',zip:'#d5a94b',rar:'#a457aa',iso:'#96a0ab',wim:'#8297a4'};
const formats=baseFormats.map(([name,label,color])=>[name,label,overrides[name] || mix(color,'#ffffff',.12)]);
const wrap = (body,size=64) => `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${body}</svg>`;
function outlined(svg) {
  return new Resvg(svg, {font:{loadSystemFonts:false,fontFiles:[fontFile,smallFontFile]}}).toString().trimEnd()+'\n';
}
function write(name, svg) {
  const target=path.join(dir,'src',name+'.svg');
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,outlined(svg));
}
const tools={
  Add:'<path d="M12 4v16M4 12h16"/>',
  Extract:'<path d="M3 8V6a2 2 0 0 1 2-2h4l2 3h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8h14"/><path d="M10 14h7m-3-3 3 3-3 3"/>',
  Test:'<path d="m4 12 5 5L20 6"/>',
  Copy:'<rect x="8" y="3" width="12" height="14" rx="2"/><path d="M5 7H4a1 1 0 0 0-1 1v11a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2"/>',
  Move:'<path d="M10 5H5a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h5M10 12h11m-4-4 4 4-4 4"/>',
  Delete:'<path d="M3 6h18M9 6V4h6v2M5 6l1 14h12l1-14M10 10v6m4-6v6"/>',
  Info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6"/><circle cx="12" cy="7.5" r=".9" fill="#263445" stroke="none"/>'
};
const manifest={showLabels:false,vivid:true,sizes:[16,20,24,32,40,48,64,96,128,256],formats:[],applications:[],toolbars:[],package:[]};
for(const [name,label,color] of formats) {
  const source=`archive/${name}`;
  write(source,stackedBook(label,color,'archive',smallFontFile,manifest.showLabels,manifest.vivid));
  for(const size of [16,20,24,32]) write(source+(size===32?'-small':'-'+size),smallIcon(label,color,'archive',size,smallFontFile,manifest.showLabels,manifest.vivid));
  manifest.formats.push({name,label,color,source,smallSource:source+'-small',sizeSources:{16:source+'-16',20:source+'-20',24:source+'-24',32:source+'-small'},target:`CPP/7zip/Archive/Icons/${name}.ico`});
}
const apps=[
  ['app',['CPP/7zip/UI/FileManager/FM.ico','CPP/7zip/UI/GUI/FM.ico','CPP/7zip/UI/FileManager/7zipLogo.ico']],
  ['install',['C/Util/7zipInstall/7zip.ico','C/Util/SfxSetup/setup.ico','CPP/7zip/Bundles/SFXSetup/setup.ico']],
  ['uninstall',['C/Util/7zipUninstall/7zipUninstall.ico']],
  ['sfx',['CPP/7zip/Bundles/SFXWin/7z.ico','CPP/7zip/Bundles/SFXCon/7z.ico']]
];
for(const [name,targets] of apps) {
  const source=`app/${name}`;
  write(source,stackedBook('RoxaZip',overrides['7z'],name,smallFontFile,manifest.showLabels,manifest.vivid));
  for(const size of [16,20,24,32]) write(source+(size===32?'-small':'-'+size),smallIcon('RoxaZip',overrides['7z'],name,size,smallFontFile,manifest.showLabels,manifest.vivid));
  manifest.applications.push({name,source,smallSource:source+'-small',sizeSources:{16:source+'-16',20:source+'-20',24:source+'-24',32:source+'-small'},targets});
}
for(const [name,geometry] of Object.entries(tools)) {
  const source=`toolbar/${name.toLowerCase()}`;
  write(source,wrap(`<g fill="none" stroke="#263445" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">${geometry}</g>`,24));
  manifest.toolbars.push({name,source,targets:[{path:`CPP/7zip/UI/FileManager/${name}.bmp`,width:48,height:36,glyphSize:28},{path:`CPP/7zip/UI/FileManager/${name}2.bmp`,width:24,height:24,glyphSize:22}]});
}
for(const [name,size] of [['StoreLogo',50],['StoreLogo300x300',300],['Square44x44Logo',44],['Square71x71Logo',71],['Square150x150Logo',150],['Square310x310Logo',310],['LargeTile',310]]) manifest.package.push({target:`Package/Assets/${name}.png`,size});
/* Wide tile: the square application icon centred on a 310x150 canvas. */
manifest.packageWide=[{target:'Package/Assets/Wide310x150Logo.png',width:310,height:150,iconSize:150}];
manifest.menu={target:'CPP/7zip/UI/Explorer/MenuLogo.bmp',size:16};
manifest.excluded=['DarkMode/lib/dmlib_demo/demo.ico'];
fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Created 197 font-independent SVG masters and resource manifest.');
