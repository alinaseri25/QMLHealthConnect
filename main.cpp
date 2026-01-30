#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickView>
#include <QQmlContext>
#include <QSurfaceFormat>      // ✅ اضافه کن
#include <QOpenGLContext>      // ✅ اضافه کن

#include "backend.h"

int main(int argc, char *argv[])
{
    // ✅ قبل از ساخت QApplication
    QSurfaceFormat format;

#ifdef Q_OS_ANDROID
    // ✅ تنظیمات OpenGL ES برای Android
    QCoreApplication::setAttribute(Qt::AA_UseOpenGLES, true);

    format.setRenderableType(QSurfaceFormat::OpenGLES);
    format.setVersion(3, 0);  // OpenGL ES 3.0 (یا 2.0 برای سازگاری بیشتر)
    format.setSwapBehavior(QSurfaceFormat::DoubleBuffer);
    format.setSamples(4);  // Anti-aliasing
    QSurfaceFormat::setDefaultFormat(format);

    QCoreApplication::setAttribute(Qt::AA_UseOpenGLES, true);
#else
    // ✅ تنظیمات OpenGL Desktop برای Windows/Linux/macOS
    format.setVersion(3, 3);                    // OpenGL 3.3+
    format.setProfile(QSurfaceFormat::CoreProfile);
    format.setSwapBehavior(QSurfaceFormat::DoubleBuffer);
    format.setSamples(4);                        // Anti-aliasing
    QSurfaceFormat::setDefaultFormat(format);

    QCoreApplication::setAttribute(Qt::AA_UseOpenGLES, false);
#endif

    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);  // مهم!



    // Qt Charts uses Qt Graphics View Framework for drawing, therefore QApplication must be used.
    QApplication app(argc, argv);

    // ✅ چک کردن OpenGL support
    qDebug() << "OpenGL Version:" << QOpenGLContext::openGLModuleType();

    Backend *myBackend = new Backend(&app);

    QQuickView viewer;

    // ✅ تنظیمات viewer
    viewer.setFormat(format);  // اعمال format به viewer

    //viewer.setMinimumSize({600, 400});
    viewer.rootContext()->setContextProperty("myBackend",myBackend);

    // The following are needed to make examples run without having to install the module
    // in desktop environments.
#ifdef Q_OS_WIN
    QString extraImportPath(QStringLiteral("%1/../../../../%2"));
#else
    QString extraImportPath(QStringLiteral("%1/../../../%2"));
#endif
    viewer.engine()->addImportPath(extraImportPath.arg(QGuiApplication::applicationDirPath(),
                                                       QString::fromLatin1("qml")));
    QObject::connect(viewer.engine(), &QQmlEngine::quit, &viewer, &QWindow::close);

    viewer.setTitle(QStringLiteral("Qt Charts QML Example Gallery"));
    viewer.setSource(QUrl("qrc:/Main.qml"));
    viewer.setResizeMode(QQuickView::SizeRootObjectToView);

    // // ✅ چک نهایی OpenGL
    // if (viewer.openglContext()) {
    //     qDebug() << "✅ OpenGL Context Created Successfully";
    //     qDebug() << "   Version:" << viewer.openglContext()->format().majorVersion()
    //              << "." << viewer.openglContext()->format().minorVersion();
    // } else {
    //     qWarning() << "❌ Failed to create OpenGL context!";
    // }

    viewer.show();

    return app.exec();
}
