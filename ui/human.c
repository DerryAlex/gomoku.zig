#include <ctype.h>
#include <stdio.h>
#include <string.h>

#define COLUMNS (15)
#define ROWS (15)

typedef enum {NONE, BLACK, WHITE} gobang_type;
#define GOBANG_TYPE_OPP(x) (BLACK + WHITE - (x))

static const char *table_chars[9] = {"┼","┷","┯","┠","┗","┏","┨","┛","┓"};

static gobang_type map[COLUMNS][ROWS];
static gobang_type player = BLACK;

void UI_draw(gobang_type type, int column, int row)
{
	map[column][row] = type;
	for (int j = 0; j < ROWS; j++)
	{
		for (int i = 0; i < COLUMNS; i++)
		{
			if (i == column && j == row && type != NONE) printf("%s", (type == BLACK)?"▲":"△");
			else if (map[i][j] == BLACK) printf("●");
			else if (map[i][j] == WHITE) printf("○");
			else printf("%s", table_chars[(j == ROWS - 1) * 1 + (j == 0) * 2 + (i == 0) * 3 + (i == COLUMNS - 1) * 6]);
		}
		printf(" %d\n", ROWS - j);
	}
	for (int i = 0; i < COLUMNS; i++) printf("%c", i + 'A');
	putchar('\n');
}

void make_move(int column, int row)
{
	if (map[column][row] != NONE)
	{
		fprintf(stderr, "Illegal operation\n");
		return;
	}
	map[column][row] = player;
	UI_draw(player, column, row);
	player = GOBANG_TYPE_OPP(player);
}

int main(int argc, char *argv[])
{
	printf("OK\n");
	printf("Input coordinate(e.g. h8)\n");
	
	char buf[256];
	int x, y;
	while (1)
	{
		scanf("%s", buf);
		if (strcmp(buf, "TURN") == 0) {
			scanf("%d,%d", &y, &x);
			make_move(x, y);
		}
		else {
			x = toupper(buf[0]) - 'A';
			if (sscanf(buf + 1, "%d", &y) <= 0) {
				fprintf(stderr, "Illegal operation\n");
				continue;
			}
			y = ROWS - y;
			if (0 <= x && x < COLUMNS && 0 <= y && y < ROWS) {
				make_move(x, y);
				printf("%d,%d\n", y, x);
			}
			else fprintf(stderr, "Illegal operation\n");
		}
	}
	return 0;
}
