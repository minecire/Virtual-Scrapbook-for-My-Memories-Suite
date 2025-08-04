read -p "This will create a MIME type for Virtual Scrapbook (.vsb) files and associate it with Virtual Scrapbook, and will install Virtual Scrapbook globally. Continue? (y/N)" 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Installing Virtual Scrapbook"
    sudo chmod +x virtual_scrapbook.x86_64
    sudo install virtual_scrapbook_icon.svg /usr/share/icons/default/
    sudo install virtual_scrapbook.x86_64 /usr/bin
    sudo install virtual_scrapbook.desktop /usr/share/applications
    echo "Adding association for .vsb files"
    sudo install application-x-virtualscrapbook.xml /usr/share/mime/packages
    sudo update-mime-database /usr/share/mime
    sudo update-desktop-database /usr/share/applications
    sudo gtk-update-icon-cache /usr/share/icons/default/ -f
fi