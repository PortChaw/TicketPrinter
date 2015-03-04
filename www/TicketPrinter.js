
var cordova = require("cordova"),
    exec = require("cordova/exec");

var TicketPrinter = function()
{
    this.options = {};
};

TicketPrinter.prototype =
{
	pingPrinter: function(printer, timeout, succeed, fail)
	{
	  if (printer.host.length > 0)
	  {
	    cordova.exec(succeed, fail, "TicketPrinter", "pingPrinter", [printer.host, printer.port, timeout]);
	  }
	},
	writeToPrinter: function(printer, timeout, stringToPrint, succeed, fail)
	{
	  if (printer.host.length > 0)
	  {
	    cordova.exec(succeed, fail, "TicketPrinter", "writeToPrinter", [printer.host, printer.port, timeout, stringToPrint]);
	  }
	},
	//sends a command to a printer asynchronously, expecting a reponse (as a string via a callback)
	sendCommand: function(printer, timeout, commandToSend, succeed, fail)
	{
	  if (printer.host.length > 0)
	  {
	    cordova.exec(succeed, fail, "TicketPrinter", "sendCommandToPrinter",
	    [
	      printer.host,
	      printer.port,
	      timeout,
	      commandToSend,
	      "oposm.TicketPrinter.printerCommandCallback"
	    ]
	    );
	  }
	},
	printerCommandCallback: function(printerCommandObj)
	{
	  //pass along to settings controller
	  //FIXME:
	  OposM.app.getController("Settings").printerCommandCallback(printerCommandObj);
	},

	discoverPrinters: function()
	{
	  cordova.exec(null, null, "TicketPrinter", "discoverPrinters", ["oposm.TicketPrinter.discoverPrintersProgressCallback"]);
	},

	discoverPrintersProgressCallback: function(printerProgressObj)
	{
	  //FIXME:
	  //pass along to settings controller
	  //OposM.app.getController("Settings").discoverPrintersProgressCallback(printerProgressObj);
	  console.log(printerProgressObj);
	},

	configurePrinter: function(printer)
	{
	  //callbacks are all handled asynchronously via third argument to Cordova plugin command
	  if (printer.host.length > 0)
	  {
	    cordova.exec(null, null, "TicketPrinter", "configurePrinter",
	      [printer.host, printer.print_type, "oposm.TicketPrinter.printerCommandCallback"]);
	  }
	}
};

var TicketPrinterInstance = new TicketPrinter();

module.exports = TicketPrinterInstance;
