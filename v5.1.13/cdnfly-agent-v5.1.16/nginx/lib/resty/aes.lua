LJ@./nginx/lib/resty/aes.luaε  Ht	  X)  X'  '  '  &-  8  X	5 ==-  8B=L X+  L K  ΐmethodcipher	size  _EVP_aes_cbc	C size  _cipher  _size _cipher func  Σ	 
?-  - B-  -	 B X- B	 X	-	 9	 	
 X
)
 9 -  '  B-  '  B- 	 B X.9	  X9	  X+  ' J 9	  X9	 B  X+  ' J -    BX  X+  ' J X-    B-  9	) BX  X   X+  ' J - 9	9	    
   B	 X+  L - 9
 B- 9
 B- 9 9+    B X
- 9 9+    B	 X+  L -  - 9B-  - 9B- 5 ==-	 D ΐ
ΐΐΐΐΐΐ	ΐ_decrypt_ctx_encrypt_ctx  EVP_CIPHER_CTX_cleanupEVP_DecryptInit_exEVP_EncryptInit_exEVP_CIPHER_CTX_initEVP_BytesToKey%salt must be 8 characters or nilbad key lengthmethodbad iviv
tableunsigned char[?]	sizemd5  




"""""###&&&&&&&'''&((**....////11111221223333344344558888899999;;<=>>ffi_new ctx_ptr_type cipher hash type ffi_copy C ffi_gc setmetatable mt self  key  salt  _cipher  _hash  hash_rounds  encrypt_ctx decrypt_ctx _cipher _hash hash_rounds _cipherLength gen_key |gen_iv xtmp_key  Α 3Β  -  '   B-  ' B-  ' B9 - 9
 , B	 X+  L - 9
     B	 X+  L - 9
 :   B	 X+  L - 
 : :  D ΐΐΐEVP_EncryptFinal_exEVP_EncryptUpdateEVP_EncryptInit_ex_encrypt_ctxint[1]unsigned char[?]  		ffi_new C ffi_str self  4s  4s_len 2max_len 1buf -out_len *tmp_len 'ctx & ° 2xΪ -  '   B-  ' B-  ' B9 - 9	 ,
 B	  X+  L - 9	 
    B	  X+  L - 9	 :
  

 B	  X+  L - 	 :
 :  

D ΐΐΐEVP_DecryptFinal_exEVP_DecryptUpdateEVP_DecryptInit_ex_decrypt_ctxint[1]unsigned char[?] ffi_new C ffi_str self  3s  3s_len 1buf -out_len *tmp_len 'ctx & «  % 4¦ σ6   ' B 9 9 9 9 9 6 6 5	 5	
 =	9
 ' B
9
 ' B
+  5 9B=9B=9B=9B=9B=9B= =+  3 =3  =3" =!3$ =#2  L  decrypt encrypt cipher 	hashsha512EVP_sha512sha384EVP_sha384sha256EVP_sha256sha224EVP_sha224	sha1EVP_sha1md5  EVP_md5EVP_CIPHER_CTX[1]typeofΊtypedef struct engine_st ENGINE;

typedef struct evp_cipher_st EVP_CIPHER;
typedef struct evp_cipher_ctx_st
{
const EVP_CIPHER *cipher;
ENGINE *engine;
int encrypt;
int buf_len;

unsigned char  oiv[16];
unsigned char  iv[16];
unsigned char buf[32];
int num;

void *app_data;
int key_len;
unsigned long flags;
void *cipher_data;
int final_used;
int block_mask;
unsigned char final[32];
} EVP_CIPHER_CTX;

typedef struct env_md_ctx_st EVP_MD_CTX;
typedef struct env_md_st EVP_MD;

const EVP_MD *EVP_md5(void);
const EVP_MD *EVP_sha(void);
const EVP_MD *EVP_sha1(void);
const EVP_MD *EVP_sha224(void);
const EVP_MD *EVP_sha256(void);
const EVP_MD *EVP_sha384(void);
const EVP_MD *EVP_sha512(void);

const EVP_CIPHER *EVP_aes_128_ecb(void);
const EVP_CIPHER *EVP_aes_128_cbc(void);
const EVP_CIPHER *EVP_aes_128_cfb1(void);
const EVP_CIPHER *EVP_aes_128_cfb8(void);
const EVP_CIPHER *EVP_aes_128_cfb128(void);
const EVP_CIPHER *EVP_aes_128_ofb(void);
const EVP_CIPHER *EVP_aes_128_ctr(void);
const EVP_CIPHER *EVP_aes_192_ecb(void);
const EVP_CIPHER *EVP_aes_192_cbc(void);
const EVP_CIPHER *EVP_aes_192_cfb1(void);
const EVP_CIPHER *EVP_aes_192_cfb8(void);
const EVP_CIPHER *EVP_aes_192_cfb128(void);
const EVP_CIPHER *EVP_aes_192_ofb(void);
const EVP_CIPHER *EVP_aes_192_ctr(void);
const EVP_CIPHER *EVP_aes_256_ecb(void);
const EVP_CIPHER *EVP_aes_256_cbc(void);
const EVP_CIPHER *EVP_aes_256_cfb1(void);
const EVP_CIPHER *EVP_aes_256_cfb8(void);
const EVP_CIPHER *EVP_aes_256_cfb128(void);
const EVP_CIPHER *EVP_aes_256_ofb(void);

void EVP_CIPHER_CTX_init(EVP_CIPHER_CTX *a);
int EVP_CIPHER_CTX_cleanup(EVP_CIPHER_CTX *a);

int EVP_EncryptInit_ex(EVP_CIPHER_CTX *ctx,const EVP_CIPHER *cipher,
        ENGINE *impl, unsigned char *key, const unsigned char *iv);

int EVP_EncryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
        const unsigned char *in, int inl);

int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);

int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx,const EVP_CIPHER *cipher,
        ENGINE *impl, unsigned char *key, const unsigned char *iv);

int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
        const unsigned char *in, int inl);

int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *outm, int *outl);

int EVP_BytesToKey(const EVP_CIPHER *type,const EVP_MD *md,
        const unsigned char *salt, const unsigned char *data, int datal,
        int count, unsigned char *key,unsigned char *iv);
	cdef__index   _VERSION	0.10	typesetmetatableC	copystringgcnewffirequire	
ddfffhijjjkkklllmmmnnnooopqs}~ΏΧΒξΪρρffi 1ffi_new 0ffi_gc /ffi_str .ffi_copy -C ,setmetatable +type *_M )mt 'ctx_ptr_type !hash  cipher 
  