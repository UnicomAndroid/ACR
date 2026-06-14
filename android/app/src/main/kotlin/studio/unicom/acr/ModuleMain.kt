package studio.unicom.acr

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.github.libxposed.api.XposedInterface
import io.github.libxposed.api.XposedModule
import io.github.libxposed.api.XposedModuleInterface

class ModuleMain : XposedModule() {

    companion object {
        private val TAG = ModuleMain::class.java.simpleName
    }

    private fun hasProp(prop: Long): Boolean {
        return (frameworkProperties and prop) != 0L
    }

    override fun onModuleLoaded(param: XposedModuleInterface.ModuleLoadedParam) {
        log(Log.INFO, TAG, "onModuleLoaded: ${param.processName}")
        log(Log.INFO, TAG, "framework: $frameworkName ($frameworkVersionCode) API $apiVersion")
        log(Log.INFO, TAG, "system supported: ${hasProp(PROP_CAP_SYSTEM)}")
        log(Log.INFO, TAG, "remote supported: ${hasProp(PROP_CAP_REMOTE)}")
        log(Log.INFO, TAG, "api protection: ${hasProp(PROP_RT_API_PROTECTION)}")
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onPackageLoaded(param: XposedModuleInterface.PackageLoadedParam) {
        log(Log.INFO, TAG, "onPackageLoaded: ${param.packageName}")
        log(Log.INFO, TAG, "default classloader is ${param.defaultClassLoader}")
    }

    override fun onPackageReady(param: XposedModuleInterface.PackageReadyParam) {
        try {
            val exampleClass = Class.forName("io.github.libxposed.example.Example", true, param.classLoader)
            val exampleMethod = exampleClass.getDeclaredMethod("method")
            val exampleConstructor = exampleClass.getDeclaredConstructor()

            hook(exampleMethod).intercept { chain ->
                log(Log.INFO, TAG, "call the following chains with the same args")
                var result = chain.proceed() as String

                log(Log.INFO, TAG, "call the following chains with different args")
                val old0 = chain.getArg(0) as String
                val new1 = Any()
                val newArgs = arrayOf(old0, new1)
                result += chain.proceed(newArgs) as String

                log(Log.INFO, TAG, "call the following chains with different this object")
                val newThis = Any()
                result += chain.proceedWith(newThis) as String
                result += chain.proceedWith(newThis, newArgs) as String

                log(Log.INFO, TAG, "call the raw method")
                result += getInvoker(exampleMethod).setType(XposedInterface.Invoker.Type.ORIGIN).invoke(chain.thisObject) as String

                result
            }

            hook(exampleMethod).intercept { chain ->
                chain.proceed()
                // for void methods, it's needed to return null because Java doesn't support unit type
                null
            }

            hook(exampleConstructor)
                .setPriority(PRIORITY_HIGHEST)
                .setExceptionMode(XposedInterface.ExceptionMode.PASSTHROUGH)
                .intercept { chain ->
                    log(Log.INFO, TAG, "thrown exception will be propagated to upper interceptors or the caller")
                    throw RuntimeException("constructor hook exception")
                }

            // call the original method
            getInvoker(exampleMethod).setType(XposedInterface.Invoker.Type.ORIGIN).invoke(Any())
            // call the special method starting from the middle of the hook chain
            getInvoker(exampleMethod).setType(XposedInterface.Invoker.Type.Chain(-50)).invokeSpecial(Any())
            // create a new instance using the original constructor
            getInvoker(exampleConstructor).setType(XposedInterface.Invoker.Type.ORIGIN).newInstance()
            // create a new special instance with full hook chain
            getInvoker(exampleConstructor).setType(XposedInterface.Invoker.Type.Chain.FULL).newInstanceSpecial(exampleClass)
            // identical to the above line, default to call with full hook chain
            getInvoker(exampleConstructor).newInstanceSpecial(exampleClass)
        } catch (t: Throwable) {
            log(Log.ERROR, TAG, "Error in onPackageLoaded", t)
        }
    }
}
