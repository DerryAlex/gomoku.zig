#ifndef __PTY_H__
#define __PTY_H__ 1

#ifdef __cplusplus
extern "C" {
#endif

extern int pty_exec(const char *file, char *const argv[], int *fd);

#ifdef __cplusplus
}
#endif

#endif