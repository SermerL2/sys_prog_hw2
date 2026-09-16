#include <stdio.h>
#include "handler.h"

int scenario_A(void);
int scenario_B(void);

int main(void) {
    if (install_fpe_handler() != 0) {
        perror("sigaction");
        return 1;
    }

    printf("== scenario A (volatile divider) ==\n");
    scenario_A();

    printf("== scenario B (volatile → local) ==\n");
    scenario_B();

    printf("Перехвачено SIGFPE: %d\n", (int)g_fpe_count);
    return 0;
}