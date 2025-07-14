#! /bin/sh

sudo pacman -S mkcert
mkcert -install
sudo pacman -Rs mkcert
