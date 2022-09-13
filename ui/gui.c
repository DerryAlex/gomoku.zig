#include "ui.h"
#include <gtk/gtk.h>

static GdkPixbuf *image_background, *image_background_down,
                 *image_background_left, *image_background_left_down,
                 *image_background_left_up, *image_background_right,
                 *image_background_right_down, *image_background_right_up,
                 *image_background_up, *image_black, *image_black_down,
                 *image_black_left, *image_black_left_down,
                 *image_black_left_up, *image_black_right,
                 *image_black_right_down, *image_black_right_up,
                 *image_black_up, *image_grey, *image_grey_down,
                 *image_grey_left, *image_grey_left_down, *image_grey_left_up,
                 *image_grey_right, *image_grey_right_down,
                 *image_grey_right_up, *image_grey_up, *image_undo, *image_ai;
static GdkPixbuf *image_resources[3][9];
static gboolean is_gui_initialized = FALSE;
static int position[COLUMNS][ROWS][2];

static GtkWidget *gobang_map[COLUMNS][ROWS];
static GtkWidget *window;

static void
gui_initialize(void)
{
	if (is_gui_initialized == TRUE) return;
	
	GError *error = NULL;
	
	/* Load images */
	image_background = gdk_pixbuf_new_from_file("data/scalable/background.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_down = gdk_pixbuf_new_from_file("data/scalable/background-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_left = gdk_pixbuf_new_from_file("data/scalable/background-left.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_left_down = gdk_pixbuf_new_from_file("data/scalable/background-left-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_left_up = gdk_pixbuf_new_from_file("data/scalable/background-left-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_right = gdk_pixbuf_new_from_file("data/scalable/background-right.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_right_down = gdk_pixbuf_new_from_file("data/scalable/background-right-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_right_up = gdk_pixbuf_new_from_file("data/scalable/background-right-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_background_up = gdk_pixbuf_new_from_file("data/scalable/background-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black = gdk_pixbuf_new_from_file("data/scalable/black.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_down = gdk_pixbuf_new_from_file("data/scalable/black-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_left = gdk_pixbuf_new_from_file("data/scalable/black-left.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_left_down = gdk_pixbuf_new_from_file("data/scalable/black-left-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_left_up = gdk_pixbuf_new_from_file("data/scalable/black-left-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_right = gdk_pixbuf_new_from_file("data/scalable/black-right.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_right_down = gdk_pixbuf_new_from_file("data/scalable/black-right-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_right_up = gdk_pixbuf_new_from_file("data/scalable/black-right-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_black_up = gdk_pixbuf_new_from_file("data/scalable/black-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey = gdk_pixbuf_new_from_file("data/scalable/grey.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_down = gdk_pixbuf_new_from_file("data/scalable/grey-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_left = gdk_pixbuf_new_from_file("data/scalable/grey-left.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_left_down = gdk_pixbuf_new_from_file("data/scalable/grey-left-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_left_up = gdk_pixbuf_new_from_file("data/scalable/grey-left-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_right = gdk_pixbuf_new_from_file("data/scalable/grey-right.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_right_down = gdk_pixbuf_new_from_file("data/scalable/grey-right-down.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_right_up = gdk_pixbuf_new_from_file("data/scalable/grey-right-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_grey_up = gdk_pixbuf_new_from_file("data/scalable/grey-up.svg", &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	
	image_resources[NONE][0] = image_background;
	image_resources[NONE][1] = image_background_down;
	image_resources[NONE][2] = image_background_up;
	image_resources[NONE][3] = image_background_left;
	image_resources[NONE][4] = image_background_left_down;
	image_resources[NONE][5] = image_background_left_up;
	image_resources[NONE][6] = image_background_right;
	image_resources[NONE][7] = image_background_right_down;
	image_resources[NONE][8] = image_background_right_up;
	image_resources[BLACK][0] = image_black;
	image_resources[BLACK][1] = image_black_down;
	image_resources[BLACK][2] = image_black_up;
	image_resources[BLACK][3] = image_black_left;
	image_resources[BLACK][4] = image_black_left_down;
	image_resources[BLACK][5] = image_black_left_up;
	image_resources[BLACK][6] = image_black_right;
	image_resources[BLACK][7] = image_black_right_down;
	image_resources[BLACK][8] = image_black_right_up;
	image_resources[GREY][0] = image_grey;
	image_resources[GREY][1] = image_grey_down;
	image_resources[GREY][2] = image_grey_up;
	image_resources[GREY][3] = image_grey_left;
	image_resources[GREY][4] = image_grey_left_down;
	image_resources[GREY][5] = image_grey_left_up;
	image_resources[GREY][6] = image_grey_right;
	image_resources[GREY][7] = image_grey_right_down;
	image_resources[GREY][8] = image_grey_right_up;
	
	image_undo = gdk_pixbuf_new_from_file_at_scale("data/scalable/undo.svg",
	                                               48, 48, TRUE, &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	image_ai = gdk_pixbuf_new_from_file_at_scale("data/scalable/ai.svg",
	                                               48, 48, TRUE, &error);
	if (error)
	{
		g_warning("%s", error->message);
		g_clear_error(&error);
	}
	
	/* Initialize position */
	for (int i = 0; i < COLUMNS; i++)
		for (int j = 0; j < ROWS; j++)
		{
			position[i][j][0] = i;
			position[i][j][1] = j;
		}
	
	is_gui_initialized = TRUE;
}

static void
gui_finalize(void)
{
	if (is_gui_initialized == FALSE) return;
	
	g_object_unref(image_background);
	g_object_unref(image_background_down);
	g_object_unref(image_background_left);
	g_object_unref(image_background_left_down);
	g_object_unref(image_background_left_up);
	g_object_unref(image_background_right);
	g_object_unref(image_background_right_down);
	g_object_unref(image_background_right_up);
	g_object_unref(image_background_up);
	g_object_unref(image_black);
	g_object_unref(image_black_down);
	g_object_unref(image_black_left);
	g_object_unref(image_black_left_down);
	g_object_unref(image_black_left_up);
	g_object_unref(image_black_right);
	g_object_unref(image_black_right_down);
	g_object_unref(image_black_right_up);
	g_object_unref(image_black_up);
	g_object_unref(image_grey);
	g_object_unref(image_grey_down);
	g_object_unref(image_grey_left);
	g_object_unref(image_grey_left_down);
	g_object_unref(image_grey_left_up);
	g_object_unref(image_grey_right);
	g_object_unref(image_grey_right_down);
	g_object_unref(image_grey_right_up);
	g_object_unref(image_grey_up);
	
	g_object_unref(image_undo);
	g_object_unref(image_ai);
	
	is_gui_initialized = FALSE;
}

static void
gobang_map_on_click(GtkGesture *gesture, guint npoints, gpointer data)
{
	if (npoints == 1) make_move(((int *)data)[0], ((int *)data)[1]);
}

static void
gobang_map_on_undo(GtkGesture *gesture, guint npoints, gpointer data)
{
	withdraw();
}

static void
gobang_map_on_ai(GtkGesture *gesture, guint npoints, gpointer data)
{
	ai_turn();
}

static inline GdkPixbuf *
gobang_map_get_image(int type, int column, int row)
{
	return image_resources[type][(row == ROWS - 1) * 1 + 
	                             (row == 0) * 2 + (column == 0) * 3 + 
	                             (column == COLUMNS - 1) * 6];
}

void
UI_draw(gobang_type type, uint8_t column, uint8_t row)
{
	gtk_image_set_from_pixbuf(GTK_IMAGE(gobang_map[column][row]),
	                          gobang_map_get_image(type, column, row));
}

static void
gui_activate(GtkApplication *app, gpointer user_data)
{
	GtkWidget *grid;
	GtkGesture *click[COLUMNS][ROWS];
	GtkWidget *label_x[COLUMNS], *label_y[ROWS];
	GtkWidget *undo_button, *ai_button;
	GtkGesture *undo_action, *ai_action;
	char buf[3] = {0, 0, 0};
	
	window = gtk_application_window_new(app);
	gtk_window_set_title(GTK_WINDOW(window), "Gobang");
	
	grid = gtk_grid_new();
	gtk_window_set_child(GTK_WINDOW(window), grid);
	
	for (int i = 0; i < COLUMNS; i++)
		for (int j = 0; j < ROWS; j++)
		{
			gobang_map[i][j] = gtk_image_new_from_pixbuf(
			                     gobang_map_get_image(NONE,
			                                          i, j) );
			gtk_image_set_pixel_size(GTK_IMAGE(gobang_map[i][j]), 48);
			
			click[i][j] = gtk_gesture_click_new();
			gtk_widget_add_controller(gobang_map[i][j],
			                          GTK_EVENT_CONTROLLER(click[i][j]));
			g_signal_connect(click[i][j], "pressed",
			                 G_CALLBACK(gobang_map_on_click), position[i][j]);
			
			gtk_grid_attach(GTK_GRID(grid), gobang_map[i][j], i, j, 1, 1);
		}
	
	for (int i = 0; i < COLUMNS; i++)
	{
		buf[0] = 'A' + i;
		label_x[i] = gtk_label_new(buf);
		gtk_grid_attach(GTK_GRID(grid), label_x[i], i, ROWS,
		                1, 1);
	}
	
	for (int i = 0; i < ROWS; i++)
	{
		if (ROWS - i >= 10)
		{
			buf[0] = '0' + (ROWS - i) / 10;
			buf[1] = '0' + (ROWS - i) % 10;
		}
		else
		{
			buf[0] = '0' + (ROWS - i) % 10;
			buf[1] = 0;
		}
		label_y[i] = gtk_label_new(buf);
		gtk_grid_attach(GTK_GRID(grid), label_y[i], COLUMNS, i,
		                1, 1);
	}
	
	undo_button = gtk_image_new_from_pixbuf(image_undo);
	gtk_image_set_pixel_size(GTK_IMAGE(undo_button), 48);
	undo_action = gtk_gesture_click_new();
	gtk_widget_add_controller(undo_button, GTK_EVENT_CONTROLLER(undo_action));
	g_signal_connect(undo_action, "pressed", G_CALLBACK(gobang_map_on_undo),
	                 NULL);
	gtk_grid_attach(GTK_GRID(grid), undo_button, COLUMNS + 1, 1,
	                1, 1);
	ai_button = gtk_image_new_from_pixbuf(image_ai);
	gtk_image_set_pixel_size(GTK_IMAGE(ai_button), 48);
	ai_action = gtk_gesture_click_new();
	gtk_widget_add_controller(ai_button, GTK_EVENT_CONTROLLER(ai_action));
	g_signal_connect(ai_action, "pressed", G_CALLBACK(gobang_map_on_ai), NULL);
	gtk_grid_attach(GTK_GRID(grid), ai_button, COLUMNS + 1, 2,
	                1, 1);
	
	gtk_widget_show(window);
}

int
UI_main(int argc, char *argv[])
{
	GtkApplication *app;
	int status;
	
	gui_initialize();
	
	app = gtk_application_new("myapp.gobang", G_APPLICATION_FLAGS_NONE);
	g_signal_connect(app, "activate", G_CALLBACK(gui_activate), NULL);
	status = g_application_run(G_APPLICATION(app), argc, argv);
	g_object_unref(app);
	
	gui_finalize();
	
	return status;
}

void
UI_info(const char *str)
{
	GtkWidget *dialog;
	dialog = gtk_message_dialog_new(GTK_WINDOW(window),
	           GTK_DIALOG_DESTROY_WITH_PARENT | GTK_DIALOG_MODAL, 
	           GTK_MESSAGE_INFO, GTK_BUTTONS_CLOSE, "%s", str);
	g_signal_connect(dialog, "response", G_CALLBACK(gtk_window_destroy), dialog);
	gtk_widget_show(dialog);
}