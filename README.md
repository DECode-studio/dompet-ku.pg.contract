# Smart IDRX Sender

`PaymentGateway` adalah sebuah *smart contract* yang dirancang untuk mempermudah pengiriman token IDRX. Keunggulan utamanya adalah fitur *fallback* otomatis yang akan menukar (swap) token USDT atau USDC milik pengguna jika saldo IDRX mereka tidak mencukupi untuk melakukan transaksi. Penukaran token ini dilakukan melalui protokol **Uniswap V2**.

-----

## ✨ Fitur Utama

  - **Transfer IDRX Langsung**: Mengirim token IDRX secara efisien jika saldo mencukupi.
  - **Swap Otomatis dari USDT/USDC**: Jika saldo IDRX kurang, kontrak akan secara otomatis menghitung kekurangan dan menukarnya dari saldo USDT atau USDC pengguna.
  - **Integrasi Uniswap V2**: Menggunakan *router* Uniswap V2 yang terpercaya untuk melakukan penukaran token.
  - **Event Logging**: Memancarkan *event* `TransferFromDuitku` untuk setiap transaksi berhasil, memudahkan pelacakan *off-chain*.
  - **Efisien**: Hasil swap langsung dikirim ke penerima akhir untuk menghemat biaya gas.

-----

## ⚙️ Cara Kerja

1.  Pengguna memanggil fungsi `transfer(penerima, jumlah)`.
2.  Kontrak memeriksa saldo IDRX pengguna.
3.  **Jika saldo IDRX cukup**: Kontrak langsung mengirimkan IDRX dari pengguna ke penerima.
4.  **Jika saldo IDRX tidak cukup**:
    a. Kontrak menghitung jumlah IDRX yang kurang.
    b. Kontrak memeriksa saldo USDT pengguna. Jika cukup untuk menutupi kekurangan, kontrak akan menarik USDT dan menukarnya dengan IDRX melalui Uniswap.
    c. Jika USDT tidak cukup, kontrak akan beralih memeriksa saldo USDC dan melakukan proses yang sama.
    d. IDRX hasil penukaran akan langsung dikirim ke alamat penerima.
    e. Jika pengguna memiliki sisa saldo IDRX, sisa saldo tersebut juga akan dikirim, sehingga total yang diterima penerima sesuai dengan permintaan awal.
5.  *Event* `TransferFromDuitku` akan dicatat di blockchain.

-----

## 🚀 Memulai Proyek

### Prasyarat

  - [Node.js](https://nodejs.org/) (versi 18 atau lebih baru)
  - npm atau yarn

### Instalasi

1.  **Clone repositori ini:**

    ```bash
    git clone [URL-repositori-Anda]
    cd [nama-folder-proyek]
    ```

2.  **Install semua dependensi:**

    ```bash
    npm install
    ```

3.  **Buat file `.env`:**
    Salin file `.env.example` menjadi `.env` dan isi variabel yang dibutuhkan.

    ```bash
    cp .env.example .env
    ```

    Isi file `.env` Anda:

    ```env
    # URL RPC dari provider node Anda (misalnya Alchemy, Infura)
    RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY"

    # Private key dari wallet yang akan digunakan untuk deploy dan test
    PRIVATE_KEY="YOUR_WALLET_PRIVATE_KEY"
    ```

-----

## 🛠️ Penggunaan

### Kompilasi Kontrak

Untuk mengkompilasi semua *smart contract* di dalam proyek, jalankan:

```bash
npx hardhat compile
```

Perintah ini juga akan menghasilkan *typechain-types* yang berguna untuk pengembangan dengan TypeScript.

### Menjalankan Tes

Proyek ini dilengkapi dengan serangkaian tes komprehensif untuk memastikan semua fungsi berjalan sesuai harapan.

```bash
npx hardhat test
```

### Deployment

1.  **Sesuaikan skrip deployment:**
    Buka file di direktori `scripts/deploy.ts`. Pastikan Anda memasukkan alamat-alamat token (IDRX, USDT, USDC) dan Uniswap V2 Router yang benar sesuai dengan jaringan target Anda (misalnya Sepolia, Polygon, dll).

2.  **Jalankan skrip deployment:**
    Ganti `sepolia` dengan nama jaringan yang Anda konfigurasikan di `hardhat.config.ts`.

    ```bash
    npx hardhat run scripts/deploy.ts --network sepolia
    ```

    Simpan alamat kontrak yang berhasil di-deploy untuk digunakan pada langkah selanjutnya.

-----

## ⚠️ PENTING: Alur Pengguna

Sebelum pengguna dapat berinteraksi dengan fungsi `transfer`, mereka **WAJIB** memberikan izin (*approval*) kepada alamat kontrak `PaymentGateway` untuk membelanjakan token mereka.

Ini harus dilakukan untuk setiap token yang mungkin akan digunakan (IDRX, USDT, dan USDC).

**Contoh (menggunakan Ethers.js):**

```javascript
import { ethers } from "ethers";

// ABI minimal untuk fungsi approve
const erc20Abi = ["function approve(address spender, uint256 amount) public returns (bool)"];

// Inisialisasi kontrak token
const idrxContract = new ethers.Contract(IDRX_TOKEN_ADDRESS, erc20Abi, signer);
const usdtContract = new ethers.Contract(USDT_TOKEN_ADDRESS, erc20Abi, signer);

const PaymentGatewayAddress = "ALAMAT_KONTRAK_HASIL_DEPLOY";
const amountToApprove = ethers.parseUnits("1000", 18); // Jumlah yang diizinkan

// Berikan approval
await idrxContract.approve(PaymentGatewayAddress, amountToApprove);
await usdtContract.approve(PaymentGatewayAddress, amountToApprove);

// Setelah approval, pengguna baru bisa memanggil fungsi transfer
// ...
```

-----

## 📜 Lisensi

Proyek ini dilisensikan di bawah **MIT License**. Lihat file `LICENSE` untuk detail lebih lanjut.