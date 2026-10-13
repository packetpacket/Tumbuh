let installEvent=null;
export function installed(){return window.matchMedia?.('(display-mode: standalone)').matches||navigator.standalone===true;}
export async function installApp(){
 if(installed())return 'Tumbuh sudah dibuka sebagai aplikasi.';
 if(installEvent){await installEvent.prompt();const choice=await installEvent.userChoice;installEvent=null;return choice.outcome==='accepted'?'Tumbuh dipasang di perangkat.':'Pemasangan dibatalkan. Anda bisa memasang nanti.';}
 return /iPad|iPhone|iPod/.test(navigator.userAgent)?'Di Safari, ketuk Bagikan → Tambahkan ke Layar Utama.':'Buka menu browser → Instal aplikasi / Tambahkan ke layar utama. Gunakan HTTPS dan browser yang mendukung PWA.';
}
export function setupPwa(){
 window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installEvent=event;});
 if('serviceWorker' in navigator&&window.isSecureContext)navigator.serviceWorker.register('./sw.js',{scope:'./'}).catch(e=>console.warn('PWA belum tersedia:',e.message));
}
