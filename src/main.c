/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Time to get this show on the road
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef HAVE_SYS_TIME_H
# include <sys/time.h>
#endif
#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#include "zmachine.h"
#include "file.h"
#include "options.h"
#include "interp.h"
#include "rc.h"
#include "stream.h"
#include "menu.h"
#include "random.h"

#include "display.h"

#if WINDOW_SYSTEM == 3
#include <Carbon/Carbon.h>
#include "carbondisplay.h"
#endif

ZMachine machine;
extern char save_fname[256];
extern char script_fname[256];

int zoom_main(int argc, char** argv)
{
  arguments args;
#ifdef HAVE_GETTIMEOFDAY
  struct timeval tv;
#endif

  machine.display_active = 0;
  
  /* Seed RNG */
#ifdef HAVE_GETTIMEOFDAY
  gettimeofday(&tv, NULL);
  random_seed(tv.tv_sec^tv.tv_usec);
#else
  random_seed((unsigned int)time(NULL));
#endif

#if WINDOW_SYSTEM != 3
  get_options(argc, argv, &args);
#else
  args.story_file = NULL;
  args.save_file = NULL;
  args.warning_level = 0;
  if (carbon_prefs.show_warnings)
    {
      args.warning_level = 1;
      if (carbon_prefs.fatal_warnings)
	args.warning_level = 2;
    }
  args.track_attr = args.track_objs = args.track_props = args.graphical = 0;
#endif
  machine.warning_level = args.warning_level;

#ifdef TRACKING
  machine.track_objects = args.track_objs;
  machine.track_attributes = args.track_attr;
  machine.track_properties = args.track_props;
#endif

  rc_load();

#if WINDOW_SYSTEM != 3  
  if (args.story_file == NULL)
    {
      rc_set_game("xxxxxx", 65535);
      display_initialise();
      args.story_file = menu_get_story();
      zmachine_load_story(args.story_file, &machine);
      rc_set_game(Address(ZH_serial), Word(ZH_release));
      display_reinitialise();
    }
  else
    {
      zmachine_load_story(args.story_file, &machine);
      rc_set_game(Address(ZH_serial), Word(ZH_release));
      display_initialise();
    }
#else
  {
    static char path[256];

    zmachine_load_story(NULL, &machine);
    FSRefMakePath(lastopenfs, path, 256);
    args.story_file = path;
    rc_set_game(Address(ZH_serial), Word(ZH_release));
    display_initialise();
  }
#endif

  {
    char  title[256];
    char* name;
    int x, len, slashpos;

    len = strlen(args.story_file);

    slashpos = -1;
    name = malloc(len+1);
    for (x=0; x<len; x++)
      {
#if WINDOW_SYSTEM != 2
	if (args.story_file[x] == '/')
	  slashpos = x;
#else
	if (args.story_file[x] == '\\')
	  slashpos = x;
#endif
      }

    for (x=slashpos+1;
	 args.story_file[x] != 0 && args.story_file[x] != '.';
	 x++)
      {
	name[x-slashpos-1] = args.story_file[x];
      }
    name[x-slashpos-1] = 0;

    sprintf(title, rc_get_name(),
	    name,
	    Word(ZH_release),
	    Address(ZH_serial));
    display_set_title(title);

    sprintf(save_fname, "%s.qut", name);
    sprintf(script_fname, "%s.txt", name);
  }
  
#ifdef DEBUG
  {
    int x;

    display_prints_c("\nFont 3: ");
    display_set_style(16);
    for (x=32; x<128; x++)
      display_printf("%c", x);
    display_set_style(0);
  }
#endif
  
  display_set_style(2);
  display_prints_c("\n\nMaze\n");
  display_set_style(0);
  display_prints_c("You are in a maze of twisty little software licences, all different.\nA warranty lurks in a corner.\n\n>read warranty\n");
  display_prints_c("WELCOME, adventurer, to ");
  display_set_style(6);
  display_prints_c("Zoom " VERSION);
  display_set_style(-4);
  display_prints_c(" Copyright (c) Andrew Hunter, 2000-2002\n");
  display_set_style(0);
  
  display_prints_c("This program is free software; you can redistribute and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\n");
  display_prints_c("This program is distributed in the hope that it will be useful, but ");
  display_set_style(2);
  display_prints_c("WITHOUT ANY WARRANTY");
  display_set_style(0);
  display_prints_c("; without even the implied warranty of ");
  display_set_style(2);
  display_prints_c("MERCHANTABILITY");
  display_set_style(0);
  display_prints_c(" or ");
  display_set_style(2);
  display_prints_c("FITNESS FOR A PARTICULAR PURPOSE");
  display_set_style(0);
  display_prints_c(". See the GNU General Public Licence for more details.\n\n");
  display_prints_c("You should have received a copy of the GNU General Public License along with this program. If not, write to the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.\n");
  display_prints_c("\nThe Zoom homepage can be located at ");
  display_set_style(4);
  display_prints_c("http://www.logicalshift.demon.co.uk/unix/zoom/");
  display_set_style(0);
  display_prints_c(" - check this page for any updates\n\n\n");
  display_set_colour(0, 6);
  display_prints_c("[ Press any key to begin ]");
  display_set_colour(0, 7);
  display_readchar(0);
  display_clear();

  machine.graphical = args.graphical;
  
  machine.display_active = 1;

  switch (machine.header[0])
    {
#ifdef SUPPORT_VERSION_3
    case 3:
      display_split(1, 1);
      display_set_more(1, 0);

      display_set_colour(0, 7); display_set_font(0);
      display_set_window(0);
      zmachine_run(3, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_4
    case 4:
      zmachine_run(4, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_5
    case 5:
      display_set_cursor(0,0);
      zmachine_run(5, args.save_file);
      break;
    case 7:
      display_set_cursor(0,0);
      zmachine_run(7, args.save_file);
      break;
    case 8:
      display_set_cursor(0,0);
      zmachine_run(8, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_6
    case 6:
      display_set_cursor(1,1);
      zmachine_run(6, args.save_file);
      break;
#endif

    default:
      zmachine_fatal("Unsupported ZMachine version %i", machine.header[0]);
      break;
    }

  stream_flush_buffer();
  display_prints_c("\n");
  display_set_colour(7, 1);
  display_prints_c("[ Press any key to exit ]");
  display_set_colour(7, 0);
  display_readchar(0);
  
  return 0;
}

