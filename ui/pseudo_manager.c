#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/select.h>
#include "pty.h"

#define BUF_SIZE (1024)

int turn = 0;
int engine_fd[2];
pid_t engine_pid[2];

void start_engine(int engine_id, char const *argv[]) {
	engine_pid[engine_id] = pty_exec(argv[engine_id], argv + 2, &engine_fd[engine_id]);
	if (engine_pid[engine_id] == -1) exit(-1);
	char command[] = "START 15\nINFO timeout_turn 10000\n";
	if (write(engine_fd[engine_id], command, strlen(command)) != strlen(command)) exit(1);
}

void start_game(void) {
	char command[] = "BEGIN\n";
	if (write(engine_fd[0], command, strlen(command)) != strlen(command)) exit(1);
}

void process(char *buf, int len) {
	int x, y;
	int line_len, offset = 0;
	char line[BUF_SIZE];
	while (offset < len) {
		if (sscanf(buf + offset, "%[^\n]", line) <= 0) break;
		line_len = strlen(line);
		if (offset + line_len < len) line_len++;
		if (sscanf(line, "%d,%d", &x, &y) == 2) {
			turn = !turn;
			line_len = sprintf(line, "TURN %d,%d\n", x, y);
			write(engine_fd[turn], line, line_len);
		}
		else {
			write(STDOUT_FILENO, buf + offset, line_len);
		}
		offset += line_len;
	}
	if (offset < len) write(STDOUT_FILENO, buf + offset, len - offset);
}

int main(int argc, char const *argv[])
{
	start_engine(0, argv + 1);
	start_engine(1, argv + 1);
	start_game();

	fd_set in_fds;
	char buf[BUF_SIZE];
	while (1) {
		FD_ZERO(&in_fds);
		FD_SET(STDIN_FILENO, &in_fds);
		FD_SET(engine_fd[turn], &in_fds);
		if (select(engine_fd[turn] + 1, &in_fds, NULL, NULL, NULL) == -1) exit(1);
		if (FD_ISSET(STDIN_FILENO, &in_fds)) {
			int num_read = read(STDIN_FILENO, buf, BUF_SIZE);
			if (num_read <= 0) exit(0);
			write(engine_fd[turn], buf, num_read);
		}
		if (FD_ISSET(engine_fd[turn], &in_fds)) {
			int num_read = read(engine_fd[turn], buf, BUF_SIZE);
			if (num_read <= 0) exit(0);
			process(buf, num_read);
		}
	}
	return 0;
}