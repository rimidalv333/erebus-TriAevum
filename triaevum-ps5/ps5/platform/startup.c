/*
 * TriAevum for the PlayStation 5 - what runs before the game's main.
 *
 * Adapted from PS5_WindWakerHD's start-up. TriAevum's main is its own
 * (oot3d_native_game.cpp), so the console's start-up is a constructor: standard error into klog and the
 * shell's splash dismissed, and where a title may keep its files.
 *
 * A title sees its own folder (/app0, which is /data/homebrew/<TITLE_ID>) and
 * nothing else of /data:
 *
 *   /app0/triaevum/     the prepared title, config and mods, copied from the PC (ps5/README.md)
 *   /app0/userdata/     logs, caches and the home/XDG directories
 *   /app0/env.txt       optional: NAME=value lines, read into the environment
 *
 * SPDX-License-Identifier: MIT
 */
#include <SDL_stdinc.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "platform.h"

/* Both copies of the environment: the console's libc keeps what setenv sets
 * apart from the `environ` SDL copies, and the runtime reads the first. */
static void
set(const char *name, const char *value, int overwrite)
{
   setenv(name, value, overwrite);
   SDL_setenv(name, value, overwrite);
}

__attribute__((constructor)) static void
ps5_startup(void)
{
   platform_init(PS5_TITLE_NAME);
   /* Standard output too: a title may not dup2 (EPERM), but stdout can be the same stream as
    * stderr, which klog reads. The runtime's logger (spdlog) opens stdout after this. */
   stdout = stderr;
   mkdir("/app0/userdata", 0777);
   mkdir("/app0/userdata/save", 0777);
   /* PS5 DevLoop's grab takes the engine's screenshots from here, and removes them */
   mkdir("/app0/userdata/screenshots", 0777);
   chmod("/app0/userdata/screenshots", 0777);
   /* The runtime makes relative paths ("logs") against the working directory, which on the
    * console is not writable. Give it one that is. */
   mkdir("/app0/userdata/logs", 0777);
   say("build 5: mkdir logs done");
   {
      /* no getcwd: it is not in the console's libc and calling it jumps into the weeds */
      const int rc = chdir("/app0/userdata");
      say("build 5: chdir /app0/userdata = %d", rc);
   }
   /* The runtime's app directory (logs, config) is SHIP_HOME; its default is "." */
   set("SHIP_HOME", "/app0/userdata", 1);
   say("build 5: SHIP_HOME set");
   set("XDG_DATA_HOME", "/app0/userdata", 1);
   set("XDG_CONFIG_HOME", "/app0/userdata", 1);
   set("HOME", "/app0/userdata", 1);
   /* TriAevum's own settings, from ps5/startup-env (see the port's README) */
   FILE *file = fopen("/app0/env.txt", "r");
   if (file) {
      char line[512];
      while (fgets(line, sizeof line, file)) {
         line[strcspn(line, "\r\n")] = 0;
         char *equals = strchr(line, '=');
         if (line[0] == '#' || !equals || equals == line)
            continue;
         *equals = 0;
         set(line, equals + 1, 1);
         say("env.txt: %s=%s", line, equals + 1);
      }
      fclose(file);
   }
}
