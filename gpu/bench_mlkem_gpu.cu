#include <chrono>
#include <functional>
#include <iostream>
#include <vector>
#include <pk.hpp>

using namespace cupqc;

// ==========================
// KEM CONFIG
// ==========================
using MLKEM768Key = decltype(ML_KEM_768()
                           + Function<function::Keygen>()
                           + Block()
                           + BlockDim<128>());

using MLKEM768Encaps = decltype(ML_KEM_768()
                              + Function<function::Encaps>()
                              + Block()
                              + BlockDim<128>());

using MLKEM768Decaps = decltype(ML_KEM_768()
                              + Function<function::Decaps>()
                              + Block()
                              + BlockDim<128>());

// ==========================
// KERNELS
// ==========================
__global__ void keygen_kernel(uint8_t* public_keys,
                              uint8_t* secret_keys,
                              uint8_t* workspace,
                              uint8_t* randombytes) {
    __shared__ uint8_t smem_ptr[MLKEM768Key::shared_memory_size];
    int block = blockIdx.x;

    auto public_key = public_keys + block * MLKEM768Key::public_key_size;
    auto secret_key = secret_keys + block * MLKEM768Key::secret_key_size;
    auto entropy    = randombytes + block * MLKEM768Key::entropy_size;
    auto work       = workspace   + block * MLKEM768Key::workspace_size;

    MLKEM768Key().execute(public_key, secret_key, entropy, work, smem_ptr);
}

__global__ void encaps_kernel(uint8_t* ciphertexts,
                              uint8_t* shared_secrets,
                              const uint8_t* public_keys,
                              uint8_t* workspace,
                              uint8_t* randombytes) {
    __shared__ uint8_t smem_ptr[MLKEM768Encaps::shared_memory_size];
    int block = blockIdx.x;

    auto shared_secret = shared_secrets + block * MLKEM768Encaps::shared_secret_size;
    auto ciphertext    = ciphertexts    + block * MLKEM768Encaps::ciphertext_size;
    auto public_key    = public_keys    + block * MLKEM768Encaps::public_key_size;
    auto entropy       = randombytes    + block * MLKEM768Encaps::entropy_size;
    auto work          = workspace      + block * MLKEM768Encaps::workspace_size;

    MLKEM768Encaps().execute(ciphertext, shared_secret, public_key, entropy, work, smem_ptr);
}

__global__ void decaps_kernel(uint8_t* shared_secrets,
                              const uint8_t* ciphertexts,
                              const uint8_t* secret_keys,
                              uint8_t* workspace) {
    __shared__ uint8_t smem_ptr[MLKEM768Decaps::shared_memory_size];
    int block = blockIdx.x;

    auto shared_secret = shared_secrets + block * MLKEM768Decaps::shared_secret_size;
    auto ciphertext    = ciphertexts    + block * MLKEM768Decaps::ciphertext_size;
    auto secret_key    = secret_keys    + block * MLKEM768Decaps::secret_key_size;
    auto work          = workspace      + block * MLKEM768Decaps::workspace_size;

    MLKEM768Decaps().execute(shared_secret, ciphertext, secret_key, work, smem_ptr);
}

// ==========================
// TIMING HELPER
// ==========================
double measure_kernel(const std::function<void()>& kernel_call, int reps) {
    double total_us = 0.0;

    for (int i = 0; i < reps; i++) {
        auto start = std::chrono::high_resolution_clock::now();

        kernel_call();
        cudaDeviceSynchronize();

        auto end = std::chrono::high_resolution_clock::now();
        total_us += std::chrono::duration<double, std::micro>(end - start).count();
    }

    return total_us / reps;
}

// ==========================
// BENCH FUNCTIONS
// Kernel-only timing
// ==========================
void bench_keygen(int batch) {
    auto workspace   = make_workspace<MLKEM768Key>(batch);
    auto randombytes = get_entropy<MLKEM768Key>(batch);

    uint8_t* d_pk = nullptr;
    uint8_t* d_sk = nullptr;

    cudaMalloc(reinterpret_cast<void**>(&d_pk), MLKEM768Key::public_key_size * batch);
    cudaMalloc(reinterpret_cast<void**>(&d_sk), MLKEM768Key::secret_key_size * batch);

    constexpr int reps = 5;

    double avg_us = measure_kernel([&]() {
        keygen_kernel<<<batch, MLKEM768Key::BlockDim>>>(d_pk, d_sk, workspace, randombytes);
    }, reps);

    std::cout << "CSV," << batch << ",keygen," << (avg_us / batch) << "\n";

    cudaFree(d_pk);
    cudaFree(d_sk);
    destroy_workspace(workspace);
    release_entropy(randombytes);
}

void bench_encaps(int batch) {
    auto workspace   = make_workspace<MLKEM768Encaps>(batch);
    auto randombytes = get_entropy<MLKEM768Encaps>(batch);

    uint8_t* d_ct = nullptr;
    uint8_t* d_pk = nullptr;
    uint8_t* d_ss = nullptr;

    cudaMalloc(reinterpret_cast<void**>(&d_ct), MLKEM768Encaps::ciphertext_size * batch);
    cudaMalloc(reinterpret_cast<void**>(&d_pk), MLKEM768Encaps::public_key_size * batch);
    cudaMalloc(reinterpret_cast<void**>(&d_ss), MLKEM768Encaps::shared_secret_size * batch);

    constexpr int reps = 5;

    double avg_us = measure_kernel([&]() {
        encaps_kernel<<<batch, MLKEM768Encaps::BlockDim>>>(d_ct, d_ss, d_pk, workspace, randombytes);
    }, reps);

    std::cout << "CSV," << batch << ",encaps," << (avg_us / batch) << "\n";

    cudaFree(d_ct);
    cudaFree(d_pk);
    cudaFree(d_ss);
    destroy_workspace(workspace);
    release_entropy(randombytes);
}

void bench_decaps(int batch) {
    auto workspace = make_workspace<MLKEM768Decaps>(batch);

    uint8_t* d_ct = nullptr;
    uint8_t* d_sk = nullptr;
    uint8_t* d_ss = nullptr;

    cudaMalloc(reinterpret_cast<void**>(&d_ct), MLKEM768Decaps::ciphertext_size * batch);
    cudaMalloc(reinterpret_cast<void**>(&d_sk), MLKEM768Decaps::secret_key_size * batch);
    cudaMalloc(reinterpret_cast<void**>(&d_ss), MLKEM768Decaps::shared_secret_size * batch);

    constexpr int reps = 5;

    double avg_us = measure_kernel([&]() {
        decaps_kernel<<<batch, MLKEM768Decaps::BlockDim>>>(d_ss, d_ct, d_sk, workspace);
    }, reps);

    std::cout << "CSV," << batch << ",decaps," << (avg_us / batch) << "\n";

    cudaFree(d_ct);
    cudaFree(d_sk);
    cudaFree(d_ss);
    destroy_workspace(workspace);
}

// ==========================
// MAIN
// ==========================
int main() {
    const std::vector<int> batches = {1, 8, 32, 128, 512, 2048, 8192};

    // Warmup
    bench_keygen(1);

    for (int batch : batches) {
        bench_keygen(batch);
        bench_encaps(batch);
        bench_decaps(batch);
    }

    return 0;
}