// Filename: gbm_simulation.s
// Assemble with: clang -o gbm_simulation gbm_simulation.s -lm
// Run with: ./gbm_simulation

.section __TEXT,__text,regular,pure_instructions
.macosx_version_min 10, 15      // Minimum macOS version
.global _main
.p2align 2

// External functions
.extern _printf                 // C standard library printf function
.extern _drand48                // C standard library drand48 function
.extern _exp                    // Exponential function
.extern _sqrt                   // Square root function
.extern _log                    // Natural logarithm function
.extern _sin                    // Sine function

// Format string for printf
.section __TEXT,__cstring
fmt:    .asciz "Final S = %f\n"

.text
_main:
    // Prologue
    stp     x29, x30, [sp, #-16]!      // Save frame pointer and return address
    mov     x29, sp

    // Initialize constants
    // Load mu (μ) into d0
    ldr     d0, =0.1                   // μ = 0.1
    // Load sigma (σ) into d1
    ldr     d1, =0.2                   // σ = 0.2
    // Load initial stock price S0 into d2
    ldr     d2, =100.0                 // S = 100.0
    // Load delta t (Δt) into d3
    ldr     d3, =0.003968253968254     // Δt = 1/252 ≈ 0.003968254
    // Load N (number of steps) into w0
    mov     w0, #252                   // N = 252
    // Initialize loop counter w1
    mov     w1, #0                     // i = 0

    // Precompute constants
    fmul    d4, d1, d1                 // d4 = σ²
    fmov    d5, #0.5                   // d5 = 0.5
    fmul    d6, d5, d4                 // d6 = 0.5 * σ²
    fmov    d7, d3                     // d7 = Δt
    fmov    d0, d3                     // Prepare Δt for sqrt
    bl      _sqrt                      // sqrt(Δt)
    fmov    d8, d0                     // d8 = sqrt(Δt)
    fsub    d9, d0, d0                 // Zero out d9

Loop:
    // Compare loop counter with N
    cmp     w1, w0
    bge     Exit                       // If i >= N, exit loop

    // Generate U1 and U2 in (0, 1)
    bl      _drand48                   // U1 in d0
    fmov    d10, d0                    // d10 = U1
    bl      _drand48                   // U2 in d0
    fmov    d11, d0                    // d11 = U2

    // Compute Z using Box-Muller transform
    fmov    d0, d10                    // d0 = U1
    bl      _log                       // d0 = ln(U1)
    fmul    d0, d0, #-2.0              // d0 = -2 * ln(U1)
    bl      _sqrt                      // d0 = sqrt(-2 * ln(U1))
    fmov    d12, d0                    // d12 = sqrt(-2 * ln(U1))
    fmul    d13, d11, #6.283185307179586476925286766559 // d13 = 2π * U2
    fmov    d0, d13                    // d0 = 2π * U2
    bl      _sin                       // d0 = sin(2π * U2)
    fmul    d14, d12, d0               // d14 = Z = sqrt(-2ln(U1)) * sin(2πU2)

    // Compute the exponent argument
    fsub    d15, d0, d0                // Zero out d15
    fsub    d15, d0, d0                // Ensure d15 is zero
    fsub    d16, d0, d0                // Zero out d16
    fsub    d17, d0, d0                // Zero out d17
    fsub    d18, d0, d0                // Zero out d18

    fsub    d15, d0, d6                // d15 = -0.5σ²
    fadd    d15, d15, d0               // d15 = μ - 0.5σ²
    fmul    d15, d15, d3               // d15 *= Δt
    fmul    d16, d1, d8                // d16 = σ * sqrt(Δt)
    fmul    d16, d16, d14              // d16 *= Z
    fadd    d17, d15, d16              // d17 = exponent argument
    fmov    d0, d17                    // Move exponent argument to d0
    bl      _exp                       // Compute exp(exponent)
    fmul    d2, d2, d0                 // S *= exp(exponent)

    // Increment loop counter
    add     w1, w1, #1
    b       Loop

Exit:
    // Prepare to call printf
    adrp    x0, fmt@PAGE               // Load format string address
    add     x0, x0, fmt@PAGEOFF
    // Move S (d2) to the stack for printf
    stp     d2, d2, [sp, #-16]!        // Allocate space and store S
    mov     x1, sp                     // Pass address of S to printf
    bl      _printf                    // Call printf

    // Epilogue
    ldp     x29, x30, [sp], #16        // Restore frame pointer and return address
    ret
