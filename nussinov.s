// Filename: nussinov.s
// Assemble with: clang -o nussinov nussinov.s
// Run with: ./nussinov

.section __TEXT,__text,regular,pure_instructions
.macosx_version_min 10, 15      // Minimum macOS version
.global _main
.p2align 2

// External functions
.extern _printf                 // C standard library printf function
.extern _malloc                 // Memory allocation
.extern _free                   // Free allocated memory
.extern _strlen                 // String length function

// Format strings
.section __TEXT,__cstring
fmt_result:    .asciz "Maximum number of base pairs: %d\n"
fmt_usage:     .asciz "Usage: ./nussinov <RNA sequence>\n"

.text
_main:
    // Prologue
    stp     x29, x30, [sp, #-16]!          // Save frame pointer and return address
    mov     x29, sp

    // Check for correct number of arguments (argc == 2)
    mov     x0, xargc                      // Load argc
    cmp     x0, #2
    bne     Usage

    // Load RNA sequence from argv[1]
    mov     x1, xargv                      // Load argv
    ldr     x1, [x1, #8]                   // Load argv[1]
    bl      _strlen                        // Get length of RNA sequence
    mov     x20, x0                        // Save sequence length (N) in x20

    // Allocate memory for DP table (N x N)
    // Calculate size: N * N * sizeof(int)
    mov     x0, x20                        // x0 = N
    mul     x0, x0, x20                    // x0 = N * N
    lsl     x0, x0, #2                     // x0 = N * N * 4 (sizeof(int))
    bl      _malloc                        // Allocate memory
    mov     x21, x0                        // Save pointer to DP table in x21

    // Initialize DP table to zero
    mov     x22, x21                       // x22 = pointer to DP table
    mov     x23, x0                        // x23 = size of DP table
    mov     x24, #0                        // x24 = zero
InitLoop:
    cmp     x23, #0
    beq     InitDone
    str     w24, [x22], #4                 // Store zero and increment pointer
    sub     x23, x23, #4                   // Decrement size by 4 bytes
    b       InitLoop
InitDone:

    // Main Nussinov algorithm
    // For loop over k = 1 to N-1
    mov     x25, #1                        // k = 1
OuterLoopK:
    cmp     x25, x20                       // if k >= N, exit loop
    bge     ComputeDone

    // For loop over i = 0 to N - k - 1
    mov     x26, #0                        // i = 0
InnerLoopI:
    sub     x27, x20, x25                  // N - k
    cmp     x26, x27                       // if i >= N - k, exit loop
    bge     NextK

    // j = i + k
    add     x28, x26, x25                  // j = i + k

    // Get base at position i and j
    mov     x0, xargv                      // Load argv
    ldr     x0, [x0, #8]                   // Load argv[1]
    add     x1, x0, x26                    // &seq[i]
    ldrb    w2, [x1]                       // base_i = seq[i]
    add     x1, x0, x28                    // &seq[j]
    ldrb    w3, [x1]                       // base_j = seq[j]

    // Check if bases can pair (A-U, C-G, G-C, U-A)
    // Simplified pairing: A-U and C-G only
    mov     w4, #0                         // match = 0
    // Check if (base_i == 'A' && base_j == 'U') || (base_i == 'U' && base_j == 'A')
    cmp     w2, #'A'
    bne     CheckCG1
    cmp     w3, #'U'
    bne     CheckCG1
    mov     w4, #1                         // match = 1
    b       ComputeScore
CheckCG1:
    cmp     w2, #'U'
    bne     CheckCG2
    cmp     w3, #'A'
    bne     CheckCG2
    mov     w4, #1                         // match = 1
    b       ComputeScore
CheckCG2:
    cmp     w2, #'C'
    bne     CheckEnd
    cmp     w3, #'G'
    bne     CheckEnd
    mov     w4, #1                         // match = 1
    b       ComputeScore
CheckEnd:

ComputeScore:
    // Get index for DP[i][j]
    // index = i * N + j
    mul     x5, x26, x20                   // x5 = i * N
    add     x5, x5, x28                    // x5 = i * N + j
    lsl     x5, x5, #2                     // x5 *= sizeof(int)
    add     x5, x21, x5                    // x5 = &DP[i][j]

    // Initialize q options
    mov     w6, #0                         // q1 = 0
    // q1 = DP[i+1][j]
    cmp     x26, x20                       // if i+1 >= N, q1 = 0
    bge     ComputeQ2
    add     x7, x26, #1                    // x7 = i + 1
    mul     x8, x7, x20                    // x8 = (i+1) * N
    add     x8, x8, x28                    // x8 = (i+1) * N + j
    lsl     x8, x8, #2                     // x8 *= sizeof(int)
    add     x8, x21, x8                    // x8 = &DP[i+1][j]
    ldr     w6, [x8]                       // q1 = DP[i+1][j]

ComputeQ2:
    mov     w9, #0                         // q2 = 0
    // q2 = DP[i][j-1]
    cmp     x28, #0                        // if j-1 < 0, q2 = 0
    beq     ComputeQ3
    sub     x10, x28, #1                   // x10 = j - 1
    mul     x11, x26, x20                  // x11 = i * N
    add     x11, x11, x10                  // x11 = i * N + (j - 1)
    lsl     x11, x11, #2                   // x11 *= sizeof(int)
    add     x11, x21, x11                  // x11 = &DP[i][j-1]
    ldr     w9, [x11]                      // q2 = DP[i][j-1]

ComputeQ3:
    mov     w12, #0                        // q3 = 0
    // q3 = DP[i+1][j-1] + match
    cmp     x26, x20                       // if i+1 >= N, q3 = 0
    bge     ComputeQ4
    cmp     x28, #0                        // if j-1 < 0, q3 = 0
    beq     ComputeQ4
    add     x13, x26, #1                   // x13 = i + 1
    sub     x14, x28, #1                   // x14 = j - 1
    mul     x15, x13, x20                  // x15 = (i+1) * N
    add     x15, x15, x14                  // x15 = (i+1) * N + (j-1)
    lsl     x15, x15, #2                   // x15 *= sizeof(int)
    add     x15, x21, x15                  // x15 = &DP[i+1][j-1]
    ldr     w12, [x15]                     // q3 = DP[i+1][j-1]
    add     w12, w12, w4                   // q3 += match

ComputeQ4:
    // q4 = max over k (i < k < j) of DP[i][k] + DP[k+1][j]
    mov     w16, #0                        // q4 = 0
    mov     x17, x26                       // k = i + 1
LoopK:
    cmp     x17, x28                       // while k < j
    bge     LoopKEnd

    // q = DP[i][k] + DP[k+1][j]
    // Get DP[i][k]
    mul     x18, x26, x20                  // x18 = i * N
    add     x18, x18, x17                  // x18 = i * N + k
    lsl     x18, x18, #2                   // x18 *= sizeof(int)
    add     x18, x21, x18                  // x18 = &DP[i][k]
    ldr     w19, [x18]                     // w19 = DP[i][k]

    // Get DP[k+1][j]
    add     x20_temp, x17, #1              // k + 1
    mul     x20_temp2, x20_temp, x20       // (k+1) * N
    add     x20_temp2, x20_temp2, x28      // (k+1) * N + j
    lsl     x20_temp2, x20_temp2, #2       // x20_temp2 *= sizeof(int)
    add     x20_temp2, x21, x20_temp2      // &DP[k+1][j]
    ldr     w20_temp, [x20_temp2]          // DP[k+1][j]

    // q = DP[i][k] + DP[k+1][j]
    add     w19, w19, w20_temp             // q = DP[i][k] + DP[k+1][j]

    // Update q4 = max(q4, q)
    cmp     w19, w16
    ble     NextKInLoop
    mov     w16, w19                       // q4 = q

NextKInLoop:
    add     x17, x17, #1                   // k++
    b       LoopK
LoopKEnd:

    // Compute DP[i][j] = max(q1, q2, q3, q4)
    mov     w21, w6                        // w21 = q1
    cmp     w9, w21                        // if q2 > w21
    ble     SkipQ2
    mov     w21, w9                        // w21 = q2
SkipQ2:
    cmp     w12, w21                       // if q3 > w21
    ble     SkipQ3
    mov     w21, w12                       // w21 = q3
SkipQ3:
    cmp     w16, w21                       // if q4 > w21
    ble     SkipQ4
    mov     w21, w16                       // w21 = q4
SkipQ4:

    // Store DP[i][j] = w21
    str     w21, [x5]

    // Increment i
    add     x26, x26, #1
    b       InnerLoopI

NextK:
    // Increment k
    add     x25, x25, #1
    b       OuterLoopK

ComputeDone:
    // The maximum number of base pairs is DP[0][N-1]
    // Get DP[0][N-1]
    sub     x28, x20, #1                   // j = N - 1
    mul     x29, x26, x20                  // x29 = 0 * N
    add     x29, x29, x28                  // x29 = 0 * N + (N - 1)
    lsl     x29, x29, #2                   // x29 *= sizeof(int)
    add     x29, x21, x29                  // x29 = &DP[0][N-1]
    ldr     w30, [x29]                     // w30 = DP[0][N-1]

    // Prepare to call printf
    adrp    x0, fmt_result@PAGE            // Load format string address
    add     x0, x0, fmt_result@PAGEOFF
    mov     w1, w30                        // Pass maximum base pairs
    bl      _printf                        // Call printf

    // Free allocated memory
    mov     x0, x21                        // Pointer to DP table
    bl      _free                          // Free memory

    // Epilogue
    ldp     x29, x30, [sp], #16            // Restore frame pointer and return address
    mov     w0, #0
    ret

Usage:
    // Prepare to call printf
    adrp    x0, fmt_usage@PAGE             // Load format string address
    add     x0, x0, fmt_usage@PAGEOFF
    bl      _printf                        // Call printf
    mov     w0, #1                         // Return 1 for error
    ldp     x29, x30, [sp], #16            // Restore frame pointer and return address
    ret
