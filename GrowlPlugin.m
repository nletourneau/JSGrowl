#include "GrowlPlugin.h"

// structure containing pointers to functions implemented by the browser
static NPNetscapeFuncs *browser;
static GrowlNotifier *growl;


// all the crap for JS callbacks
static NPObject *so = NULL;

// big hammer!
static bool hasMethod(NPObject* obj, NPIdentifier methodName)
{
  return true;
}

// the meat of the JS calls, passes everything through to growl.
static bool invoke(NPObject* obj, NPIdentifier methodName, const NPVariant *args, uint32_t argCount, NPVariant *result)
{
  char *name = browser->utf8fromidentifier(methodName);
  if(name)
  {
    result->type = NPVariantType_Bool;
    result->value.boolValue = false;

    if(!strcmp(name, "notify"))
    {
      if (argCount == 2 || argCount == 3)
      {
        if (args[0].type == NPVariantType_String && args[1].type == NPVariantType_String)
        {
          NSString *title = [NSString stringWithCString:args[0].value.stringValue.UTF8Characters
                                               encoding:NSUTF8StringEncoding];
          NSString *description = [NSString stringWithCString:args[1].value.stringValue.UTF8Characters
                                                     encoding:NSUTF8StringEncoding];

          if (argCount == 2)
          {
            [growl notifyWithTitle:title description:description];
            result->value.boolValue = true;
          }
          else if (args[2].type == NPVariantType_String)
          {
            NSString *url = [NSString stringWithCString:args[2].value.stringValue.UTF8Characters
                                               encoding:NSUTF8StringEncoding];
            [growl notifyWithTitle:title description:description iconURL:url];
            result->value.boolValue = true;            
          }
        }
      }
      return true;
    }
    else if(!strcmp(name, "isInstalled"))
    {
      result->value.boolValue = [growl isInstalled];
      return true;
    }
    else if(!strcmp(name, "isRunning"))
    {
      result->value.boolValue = [growl isRunning];
      return true;
    }
  }
  return false;
}

// no properties to show to JS
static bool hasProperty(NPObject *obj, NPIdentifier propertyName)
{
	return false;
}

// no properties to show to JS
static bool getProperty(NPObject *obj, NPIdentifier propertyName, NPVariant *result)
{
	return false;
}

// object references for passing to the browser
static NPClass npcRefObject = {
  NP_CLASS_STRUCT_VERSION,
  NULL,
  NULL,
  NULL,
  hasMethod,
  invoke,
  NULL,
  hasProperty,
  getProperty,
  NULL,
  NULL,
};


// Symbol called once by the browser to initialize the plugin
NPError NP_Initialize(NPNetscapeFuncs* browserFuncs)
{  
  // save away browser functions
  browser = browserFuncs;
  growl = [[GrowlNotifier alloc] init];
  return NPERR_NO_ERROR;
}

// Symbol called by the browser to get the plugin's function list
NPError NP_GetEntryPoints(NPPluginFuncs* pluginFuncs)
{
  pluginFuncs->version = 11;
  pluginFuncs->size = sizeof(pluginFuncs);
  pluginFuncs->newp = NPP_New;
  pluginFuncs->destroy = NPP_Destroy;
  pluginFuncs->setwindow = NPP_SetWindow;
  pluginFuncs->event = NPP_HandleEvent;
  pluginFuncs->getvalue = NPP_GetValue;
  
  return NPERR_NO_ERROR;
}

// Symbol called once by the browser to shut down the plugin
void NP_Shutdown(void)
{
  [growl release];
}

// Called to create a new instance of the plugin
NPError NPP_New(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved)
{
  NPBool supportsCoreGraphics;
  if (browser->getvalue(instance, NPNVsupportsCoreGraphicsBool, &supportsCoreGraphics) != NPERR_NO_ERROR)
    supportsCoreGraphics = FALSE;
  
  if (!supportsCoreGraphics)
    return NPERR_INCOMPATIBLE_VERSION_ERROR;
  
  browser->setvalue(instance, NPPVpluginDrawingModel, (void *)NPDrawingModelCoreGraphics);
  
  return NPERR_NO_ERROR;
}

// Called to destroy an instance of the plugin
NPError NPP_Destroy(NPP instance, NPSavedData** save)
{
  free(instance->pdata);
  browser->releaseobject(so);
  
  return NPERR_NO_ERROR;
}

NPError NPP_GetValue(NPP instance, NPPVariable variable, void *value)
{
	switch(variable) {
    default:
      return NPERR_GENERIC_ERROR;
    case NPPVpluginScriptableNPObject:
      if(!so)
        so = browser->createobject(instance, &npcRefObject);
      browser->retainobject(so);
      *(NPObject **)value = so;
      break;
	}
	return NPERR_NO_ERROR;
}

// UNUSED NPAPI STUFF
// Called to update a plugin instances's NPWindow
NPError NPP_SetWindow(NPP instance, NPWindow* window)
{
  return NPERR_NO_ERROR;
}

int16_t NPP_HandleEvent(NPP instance, void* event)
{
  return 0;
}
