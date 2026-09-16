#define _GNU_SOURCE
#include "handler.h"
#include <ucontext.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

volatile sig_atomic_t g_fpe_count = 0;

/* Упрощённый декодер длины div/idiv. Возвращает длину инструкции или -1. */
static int decode_div_idiv_len(const uint8_t *code) {
    int i = 0;

    /* Пропуск префиксов REX 0x40..0x4F */
    if ((code[i] & 0xF0) == 0x40) i++;

    uint8_t opcode = code[i];
    if (opcode != 0xF6 && opcode != 0xF7) return -1;
    i++;

    uint8_t modrm = code[i];
    uint8_t reg   = (modrm >> 3) & 7;
    if (reg != 6 && reg != 7) return -1;   /* /6 = div, /7 = idiv */
    i++;

    uint8_t mod = (modrm >> 6) & 3;
    uint8_t rm  = modrm & 7;

    if (mod != 3) {                 /* операнд — память */
        if (rm == 4) i++;           /* SIB */
        if (mod == 0 && rm == 5) i += 4;
        else if (mod == 1)       i += 1;
        else if (mod == 2)       i += 4;
    }

    return i;
}

static void fpe_handler(int sig, siginfo_t *info, void *ctx) {
    (void)sig;
    if (info->si_code != FPE_INTDIV) return;

    ucontext_t *uc = (ucontext_t *)ctx;
    uintptr_t rip  = (uintptr_t)uc->uc_mcontext.gregs[REG_RIP];

    int len = decode_div_idiv_len((const uint8_t *)rip);
    if (len <= 0) {
        fprintf(stderr, "[handler] не распознал инструкцию по адресу %p\n",
                (void *)rip);
        return;   /* вернёмся — программа упадёт с SIGFPE повторно */
    }

    /* Имитируем "деление на 0 = 0" */
    uc->uc_mcontext.gregs[REG_RAX] = 0;   /* частное */
    uc->uc_mcontext.gregs[REG_RDX] = 0;   /* остаток */
    uc->uc_mcontext.gregs[REG_RIP] = rip + len;

    g_fpe_count++;
}

int install_fpe_handler(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = fpe_handler;
    sa.sa_flags     = SA_SIGINFO | SA_RESTART;
    sigemptyset(&sa.sa_mask);
    return sigaction(SIGFPE, &sa, NULL);
}