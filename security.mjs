export function createCloudClient(supabase,config){return supabase.createClient(config.supabaseUrl,config.supabaseKey,{auth:{experimental:{passkey:true}}});}
export async function securityCall(client,action,pin=null,oldPin=null){
 const {data,error}=await client.rpc('tumbuh_security',{p_action:action,p_pin:pin,p_old_pin:oldPin});
 if(error)throw new Error(/function|schema cache/i.test(error.message)?'Jalankan supabase-security.sql terlebih dahulu di Supabase.':error.message);
 if(!data?.ok)throw new Error(data?.error||'Akun belum dapat dibuka.');return data;
}
export function validPin(pin){return /^\d{6}$/.test(pin);}
export function passkeySupported(){return !!(globalThis.isSecureContext&&globalThis.PublicKeyCredential&&navigator.credentials);}
export async function authenticatePasskey(client,expectedUserId){
 if(!passkeySupported())throw new Error('Passkey membutuhkan HTTPS dan browser/perangkat yang mendukung. Gunakan PIN pada perangkat ini.');
 const {data,error}=await client.auth.signInWithPasskey();if(error)throw error;
 if(data?.user?.id!==expectedUserId){await client.auth.signOut();throw new Error('Passkey berbeda akun. Masuk ulang dengan Google yang sesuai.');}
 return securityCall(client,'passkey');
}
