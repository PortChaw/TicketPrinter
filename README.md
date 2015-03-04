Cordova iOS plugin for interfacing with ticket (receipt) printers, namely Bixolon thermal and impact printers.

### Installing
* install Plugman (globally)
  * `sudo npm install -g plugman`
* install Cordova plugins (from your application's Cordova directory):
  * `plugman install --platform ios --project platforms/ios --plugin https://github.com/PortChaw/TicketPrinter.git`
  * _Or_ when developing _this plugin itself_, the best approach is to install it from the local files system. Assuming you've cloned the this plugin at the same level as your project's root, this should work:
  `plugman install --platform ios --project platforms/ios --plugin ../../../TicketPrinter`
  * NB: it may be necessary to re-run this command to pick up changes since this is a copy operation rather than a symbolic link.  TODO: improve this process.
  * to _uninstall_ the plugin : `plugman uninstall --platform ios --project platforms/ios --plugin com.portchaw.ticketprinter` (from your application's Cordova directory)

* or 
  `cca plugin add ../../../TicketPrinter`
