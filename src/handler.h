#ifndef HANDLER_H
#define HANDLER_H

#include <signal.h>

/* Установить обработчик SIGFPE. Возвращает 0 при успехе. */
int install_fpe_handler(void);

/* Счётчик перехваченных SIGFPE — для отчёта. */
extern volatile sig_atomic_t g_fpe_count;

#endif