import {excelDate,ageAt} from './core.mjs';
const norm=v=>String(v??'').normalize('NFKC').toLowerCase().replace(/[^a-z0-9]/g,'');
const aliases={full_name:['namalengkap','namalengkapanak','namaanak','fullname'],nickname:['namapanggilan','panggilan','nickname'],birth_place:['tempatlahir','tempatkelahiran','birthplace'],birth_date:['tanggallahir','tgllahir','tanggalkelahiran','birthdate','dateofbirth','dob']};
const fieldOf=v=>Object.keys(aliases).find(k=>aliases[k].includes(norm(v)));
function validate(row,label,errors){try{row.full_name=String(row.full_name??'').trim();if(!row.full_name)return null;row.nickname=String(row.nickname??'').trim();row.birth_place=String(row.birth_place??'').trim();row.birth_date=excelDate(row.birth_date);ageAt(row.birth_date);row.active=true;return row;}catch(e){errors.push(`${label}: ${row.full_name} — ${e.message}`);return null;}}
function tableRows(matrix,sheetName,errors){
 for(let h=0;h<Math.min(matrix.length,40);h++){
  const map={};const width=Math.max(matrix[h]?.length||0,matrix[h+1]?.length||0);
  for(let col=0;col<width;col++){const upper=fieldOf(matrix[h]?.[col]),lower=fieldOf(matrix[h+1]?.[col]);if(upper)map[upper]=col;if(lower&&!upper)map[lower]=col;}
  if(map.full_name===undefined||map.birth_date===undefined)continue;
  // A table has at least two field labels in its header row. Identity panels do not.
  if((matrix[h]||[]).filter(v=>fieldOf(v)).length<2)continue;
  const out=[];
  for(let ri=h+1;ri<matrix.length;ri++){const row=matrix[ri]||[];const name=String(row[map.full_name]??'').trim();if(norm(name)==='out')break;if(!name||fieldOf(name))continue;const r=validate({full_name:name,nickname:row[map.nickname],birth_place:row[map.birth_place],birth_date:row[map.birth_date]},`${sheetName}, baris ${ri+1}`,errors);if(r)out.push(r);}
  return out;
 }
 return null;
}
function identityRow(matrix,sheetName,errors){const row={};for(let ri=0;ri<Math.min(matrix.length,15);ri++){const values=matrix[ri]||[];for(let col=0;col<values.length;col++){const key=fieldOf(values[col]);if(!key)continue;for(let j=col+1;j<Math.min(col+5,values.length);j++){const v=values[j];if(v===null||v===undefined||v==='')continue;if(fieldOf(v))break;row[key]=v;break;}}}if(!row.full_name||row.birth_date===undefined)return null;return validate(row,`Sheet ${sheetName}`,errors);}
export function parseChildrenWorkbook(book,XLSX){
 const errors=[];const preferred=book.SheetNames.find(n=>norm(n)==='dataanakokt')||book.SheetNames.find(n=>norm(n)==='okt');
 const read=name=>XLSX.utils.sheet_to_json(book.Sheets[name],{header:1,defval:null,raw:true});
 let rows=[];
 if(preferred){rows=tableRows(read(preferred),preferred,errors)||[];}else{
  for(const name of book.SheetNames){const found=tableRows(read(name),name,errors);if(found?.length){rows=found;break;}}
  if(!rows.length&&!errors.length)for(const name of book.SheetNames){const row=identityRow(read(name),name,errors);if(row)rows.push(row);}
 }
 if(errors.length)throw Error(`Impor dibatalkan agar data tidak hilang. ${errors.slice(0,3).join(' ')}${errors.length>3?' Ada '+(errors.length-3)+' kesalahan lain.':''}`);
 if(!rows.length)throw Error('Data identitas anak belum ditemukan. Pilih daftar anak, file dengan sheet OKT, atau file perkembangan per anak. Template indikator saja tidak berisi identitas anak.');
 return[...new Map(rows.map(r=>[r.full_name.toLowerCase()+'|'+r.birth_date,r])).values()];
}
