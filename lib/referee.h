#ifndef __REFEREE_H__
#define __REFEREE_H__

#ifdef __cpluscplus
extern "C" {
#endif

extern void referee_init();
extern void referee_update(int pos_x, int pos_y);
extern int referee_check_win();
extern int referee_check_legal();

#ifdef __cpluscplus
}
#endif

#endif /* __REFEREE_H__ */