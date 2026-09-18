#include "scenarios.h"
#include <stdio.h>

/* Значение читается из volatile — оптимизатор не может его предсказать. */
volatile int g_zero = 0;

/* Сценарий A: делитель сам volatile. */
__attribute__((noinline))
int scenario_A(void) {
    volatile int a = 10;
    volatile int b = g_zero;
    int result = a / b;
    if (b == 0)
        printf("  A: b is 0     (result=%d)\n", result);
    else
        printf("  A: b is NOT 0 (result=%d)\n", result);
    return result;
}

/* Сценарий B: 0 читается в обычную локальную переменную. */
__attribute__((noinline))
int scenario_B(void) {
    volatile int a = 10;
    int b = g_zero;              /* volatile → локальная */
    int result = a / b;          /* UB, если b == 0 */
    if (b == 0)
        printf("  B: b is 0     (result=%d)\n", result);
    else
        printf("  B: b is NOT 0 (result=%d)\n", result);
    return result;
}