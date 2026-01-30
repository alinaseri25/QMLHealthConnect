package org.verya.QMLHealthConnect

import android.content.Intent
import android.os.Bundle
import org.qtproject.qt.android.bindings.QtActivity

class MainActivity : QtActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        HealthBridge.init(this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == HealthBridge.REQUEST_CODE_PERMISSIONS) {
            HealthBridge.onPermissionResult(requestCode, resultCode)
        }
    }
}
