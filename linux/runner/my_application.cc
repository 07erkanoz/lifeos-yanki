#include "my_application.h"
#include <initializer_list>

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

#include "flutter/generated_plugin_registrant.h"

void register_quick_search(FlView* view, GtkWindow* window);

// LifeOS Yankı: LifeOS's voice assistant.
static constexpr const char* kTitle = "LifeOS Yank\xc4\xb1";
static constexpr const char* kIcon = "lifeos_yanki.png";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Yankı draws its own frame: on KWin, ask that no caption be drawn over it.
static void own_decorations_cb(GtkWidget* window, gpointer) {
#ifdef GDK_WINDOWING_WAYLAND
  GdkWindow* gdk_window = gtk_widget_get_window(window);
  if (gdk_window == nullptr || !GDK_IS_WAYLAND_WINDOW(gdk_window)) return;
  gdk_wayland_window_announce_csd(gdk_window);
#endif
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_title(window, kTitle);
  gtk_window_set_decorated(window, FALSE);
  g_signal_connect_after(window, "realize", G_CALLBACK(own_decorations_cb),
                         nullptr);
  gtk_window_set_default_size(window, 1280, 720);

  // See-through: the floating orb is a card over the desktop.
  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* rgba = gdk_screen_get_rgba_visual(screen);
  const gboolean see_through =
      rgba != nullptr && gdk_screen_is_composited(screen);
  if (see_through) {
    gtk_widget_set_visual(GTK_WIDGET(window), rgba);
    gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
  }

  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable != nullptr) {
    g_autofree gchar* directory = g_path_get_dirname(executable);
    g_autofree gchar* icon = g_build_filename(directory, "data", "flutter_assets",
        "assets", "branding", kIcon, nullptr);
    gtk_window_set_default_icon_name(APPLICATION_ID);
    gtk_window_set_icon_name(window, APPLICATION_ID);
    g_autoptr(GdkPixbuf) source = gdk_pixbuf_new_from_file(icon, nullptr);
    if (source != nullptr) {
      GList* icons = nullptr;
      for (const int size : {32, 48, 64, 128, 256}) {
        GdkPixbuf* scaled = gdk_pixbuf_scale_simple(source, size, size,
                                                   GDK_INTERP_BILINEAR);
        if (scaled != nullptr) icons = g_list_append(icons, scaled);
      }
      gtk_window_set_default_icon_list(icons);
      gtk_window_set_icon_list(window, icons);
      g_list_free_full(icons, g_object_unref);
    }
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);
  // Skia: Impeller stuttered the animations here. LIFEOS_CIZIM=impeller to
  // compare.
  fl_dart_project_set_enable_impeller(
      project, g_strcmp0(g_getenv("LIFEOS_CIZIM"), "impeller") == 0);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, see_through ? "#00000000" : "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  // No window until Dart shows it: full screen, the floating orb, or none
  // while it only listens (--arka).
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  register_quick_search(view, window);
  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }
  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
