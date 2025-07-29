# Virtual Scrapbook for My Memories Suite

Virtual Scrapbook is a project meant for creating Virtual Scrapbooks out of My Memories Suite projects

## Purchase My Memories Suite:
https://www.mymemories.com/mms/my_memories_suite

## How to Use
In order to use, create a scrapbook using My Memories Suite, and open the directory of the project using Virtual Scrapbook.
Push Esc to return to the menu, and left and right arrows to navigate the scrapbook.
You can also push R to refresh the scrapbook after making changes in MMS.

## More Options
Virtual Scrapbook offers a few extra options for those wanting extra customization

### Custom Covers
Create a custom cover by placing pngs titled cover_outside, cover_inside_left, and cover_inside_right inside the main project directory.

### Multiple Sections
Create multiple sections by placing multiple projects in a single directory. A file in the main directory titled 'sections.txt' can list the sections in order to order them properly. You can move between sections in the editor by pressing Shift + Left or Shift + Right.

You can also create a table of contents by creating a text object in My Memories Suite and writing `[CONTENTS]` (with brackets) in whatever font you would like to use, or create a custom table of contents using pagelinks.

### Links
Add links by placing the following text inside a My Memories Suite text object:

`[WEBLINK https://your.url/]this is a link to your.url!![/]`

`[PAGELINK your/section 12]this is a link to page 12 of your/section![/]`

Make sure to include the full path to the section in the link from the base scrapbook directory

#### Note: Virtual Scrapbook does not automatically style links to look clickable in order to give more options for customization. It is up to you to format links to make it clear you can click them.

## Web Version
Although it is quite a bit slower and glitchier due to the limitations of web generally, and godot's web exporter specifically, you can use the web build here:
https://minecire.github.io/Virtual-Scrapbook-for-My-Memories-Suite/

## Build Info
This is a project creating using Godot Engine 4.4, and as such you need to install Godot to build.

Godot can be downloaded here:
https://godotengine.org/download/archive/4.4-stable/
