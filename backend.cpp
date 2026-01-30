#include "backend.h"

Backend::Backend(QObject *parent)
    : QObject{parent}
{}

void Backend::onUpdateRequest()
{
    //qDebug() << QString("inja ooooooooooomad");
    readData();
}


void Backend::permissionRequest()
{
#ifdef Q_OS_ANDROID
    // ✅ دریافت Activity (نه Application Context)
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << ("❌ Activity is invalid!");
        return;
    }

    // Init
    QJniObject::callStaticMethod<void>(
        "org/verya/QMLHealthConnect/HealthBridge",
        "init",
        "(Landroid/content/Context;)V",
        activity.object()
        );

    qDebug() << ("=== 🔐 Health Connect Test ===\n");

    // Check permissions
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "checkPermissions",
        "()Ljava/lang/String;"
        );
    qDebug() << ("🔑 Current: " + result.toString());

    // ✅ Request permissions با پاس دادن Activity
    qDebug() << ("\n🚀 Requesting permissions...");
    result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "requestPermissions",
        "(Landroid/app/Activity;)Ljava/lang/String;",
        activity.object()
        );

    qDebug() << ("✅ Result: " + result.toString());
    qDebug() << ("\n💡 If dialog appeared, grant permissions then press Read.");

#else
    qDebug() << "Not Android";
#endif
}

void Backend::readData()
{
    hList.clear();
    wList.clear();
#ifdef Q_OS_ANDROID
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        qDebug() << ("Context is invalid!");
        return;
    }
    QString status;
    QJniObject result;

    permissionRequest();

    //Height
    result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "readHeight",
        "()Ljava/lang/String;"
        );

    status = result.toString();
    QJsonDocument *document = new QJsonDocument(QJsonDocument::fromJson(status.toUtf8()));
    QJsonArray arr = document->array();
    for(uint32_t i = 0 ; i < arr.size() ; i++)
    {
        QPointF point;
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dateTime = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        point.setX(dateTime.toMSecsSinceEpoch());
        point.setY(obj["height_m"].toDouble());
        hList.append(point);
        //ui->txtData->append(QString("قد : %1 و زمان ثبت : %2").arg(obj["height_m"].toDouble()).arg(dateTime.toString(QString("yyyy/mm/dd hh:MM:ss"))));
        //series1->append(dateTime.toSecsSinceEpoch(),(obj["height_m"].toDouble() * 100));
    }

    //Weight
    result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "readWeight",
        "()Ljava/lang/String;"
        );

    status = result.toString();
    document = new QJsonDocument(QJsonDocument::fromJson(status.toUtf8()));
    arr = document->array();
    for(uint32_t i = 0 ; i < arr.size() ; i++)
    {
        QPointF point;
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dateTime = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        point.setX(dateTime.toMSecsSinceEpoch());
        point.setY(obj["weight_kg"].toDouble());
        wList.append(point);
        //ui->txtData->append(QString("وزن : %1 و زمان ثبت : %2").arg(obj["weight_kg"].toDouble()).arg(dateTime.toString(QString("yyyy/mm/dd hh:MM:ss"))));
        //series2->append(dateTime.toSecsSinceEpoch(),obj["weight_kg"].toDouble());
    }
    emit newDataRead(hList,wList);

#else
    qDebug() << "Not Android";
#endif
}
