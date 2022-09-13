#define _XOPEN_SOURCE 600
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>

int pty_exec(const char *file, char *const argv[], int *fd)
{
	int master_fd = posix_openpt(O_RDWR | O_NOCTTY);
	if (master_fd == -1) return -1;
	if (grantpt(master_fd) == -1) {
		close(master_fd);
		return -1;
	}
	if (unlockpt(master_fd) == -1) {
		close(master_fd);
		return -1;
	}
	char slave_name[256];
	if (ptsname_r(master_fd, slave_name, 256) != 0) {
		close(master_fd);
		return -1;
	}
	pid_t child_pid = fork();
	if (child_pid == -1) {
		close(master_fd);
		return -1;
	}
	if (child_pid != 0) { // parent
		*fd = master_fd;
		return child_pid;
	}
	// child
	if (setsid() == -1) exit(1);
	close(master_fd);
	int slave_fd = open(slave_name, O_RDWR);
	if (slave_fd == -1) exit(1);
	struct termios tp;
	if (tcgetattr(slave_fd, &tp) == -1) exit(1);
	tp.c_lflag &= ~ECHO;
	if (tcsetattr(slave_fd, TCSANOW, &tp) == -1) exit(1);
	if (dup2(slave_fd, STDIN_FILENO) != STDIN_FILENO) exit(1);
	if (dup2(slave_fd, STDOUT_FILENO) != STDOUT_FILENO) exit(1);
	if (dup2(slave_fd, STDERR_FILENO) != STDERR_FILENO) exit(1);
	if (slave_fd > STDERR_FILENO) close(slave_fd);
	execvp(file, argv);
	exit(1);
}