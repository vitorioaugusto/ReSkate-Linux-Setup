#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "embedded_setup.h"

static void die(const char *message)
{
    fprintf(stderr, "ReSkate Setup: %s\n", message);
    exit(EXIT_FAILURE);
}

static int exists_in_path(const char *name)
{
    const char *path = getenv("PATH");
    if (!path) return 0;

    char *copy = strdup(path);
    if (!copy) return 0;

    char *save = NULL;
    for (char *dir = strtok_r(copy, ":", &save);
         dir;
         dir = strtok_r(NULL, ":", &save))
    {
        char candidate[PATH_MAX];
        snprintf(candidate, sizeof(candidate), "%s/%s", *dir ? dir : ".", name);
        if (access(candidate, X_OK) == 0)
        {
            free(copy);
            return 1;
        }
    }

    free(copy);
    return 0;
}

static void extract_embedded_setup(char *output_path, size_t output_size)
{
    const char *home = getenv("HOME");
    if (!home || !*home) die("HOME is not defined.");

    char cache_dir[PATH_MAX];
    snprintf(cache_dir, sizeof(cache_dir), "%s/.cache", home);
    mkdir(cache_dir, 0755);

    char app_dir[PATH_MAX];
    snprintf(app_dir, sizeof(app_dir), "%s/.cache/reskate-setup", home);
    if (mkdir(app_dir, 0755) != 0 && errno != EEXIST)
        die("could not create ~/.cache/reskate-setup.");

    snprintf(output_path, output_size,
             "%s/reskate-setup-final-safe.sh", app_dir);

    FILE *file = fopen(output_path, "wb");
    if (!file) die("could not extract the embedded setup script.");

    if (fwrite(embedded_setup, 1, embedded_setup_len, file) != embedded_setup_len)
    {
        fclose(file);
        die("failed to write the embedded setup script.");
    }

    fclose(file);
    chmod(output_path, 0700);
}

static int run_current_terminal(const char *script, int argc, char **argv)
{
    char **args = calloc((size_t)argc + 2, sizeof(char *));
    if (!args) die("out of memory.");

    args[0] = "bash";
    args[1] = (char *)script;
    for (int i = 1; i < argc; ++i) args[i + 1] = argv[i];
    args[argc + 1] = NULL;

    execvp("bash", args);
    perror("bash");
    return EXIT_FAILURE;
}

static int run_terminal(const char *terminal, const char *script, int argc, char **argv)
{
    if (!strcmp(terminal, "konsole"))
    {
        char **args = calloc((size_t)argc + 6, sizeof(char *));
        int n = 0;
        args[n++] = "konsole";
        args[n++] = "--hold";
        args[n++] = "-e";
        args[n++] = "bash";
        args[n++] = (char *)script;
        for (int i = 1; i < argc; ++i) args[n++] = argv[i];
        args[n] = NULL;
        execvp("konsole", args);
    }
    else if (!strcmp(terminal, "gnome-terminal"))
    {
        char **args = calloc((size_t)argc + 5, sizeof(char *));
        int n = 0;
        args[n++] = "gnome-terminal";
        args[n++] = "--";
        args[n++] = "bash";
        args[n++] = (char *)script;
        for (int i = 1; i < argc; ++i) args[n++] = argv[i];
        args[n] = NULL;
        execvp("gnome-terminal", args);
    }
    else if (!strcmp(terminal, "xfce4-terminal"))
    {
        char command[PATH_MAX * 2];
        snprintf(command, sizeof(command), "bash '%s'", script);
        execlp("xfce4-terminal", "xfce4-terminal", "--hold", "-e", command, (char *)NULL);
    }
    else if (!strcmp(terminal, "xterm"))
    {
        execlp("xterm", "xterm", "-hold", "-e", "bash", script, (char *)NULL);
    }

    perror(terminal);
    return EXIT_FAILURE;
}

int main(int argc, char **argv)
{
    char script_path[PATH_MAX];
    extract_embedded_setup(script_path, sizeof(script_path));

    if (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO))
        return run_current_terminal(script_path, argc, argv);

    const char *terms[] = {"konsole", "gnome-terminal", "xfce4-terminal", "xterm"};
    for (size_t i = 0; i < sizeof(terms) / sizeof(terms[0]); ++i)
        if (exists_in_path(terms[i]))
            return run_terminal(terms[i], script_path, argc, argv);

    die("no supported terminal emulator was found.");
    return EXIT_FAILURE;
}
