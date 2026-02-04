#include "backend.h"

Backend::Backend(QObject *parent)
    : QObject{parent}
{
    readData();
}

void Backend::onUpdateRequest()
{
    readData();
}

void Backend::writeHeight(double heightMeters)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << "❌ Activity is invalid!";
        emit heightWritten(false, "Activity is invalid");
        return;
    }

    // بررسی اعتبار مقدار قد (بین 0.5 تا 2.5 متر)
    if (heightMeters < 0.1 || heightMeters > 3) {
        qDebug() << "❌ Invalid height value: " << heightMeters;
        emit heightWritten(false, QString("مقدار قد نامعتبر است: %1 متر").arg(heightMeters));
        return;
    }

    // فراخوانی متد Kotlin برای نوشتن قد
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeHeight",
        "(D)Ljava/lang/String;",
        heightMeters
        );

    QString status = result.toString();

    // بررسی موفقیت‌آمیز بودن
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    emit heightWritten(success, status);

#else
    qDebug() << "Not Android - Height write skipped";
    emit heightWritten(false, "Not running on Android");
#endif
}

void Backend::writeWeight(double weightKg)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << "❌ Activity is invalid!";
        emit weightWritten(false, "Activity is invalid");
        return;
    }

    // بررسی اعتبار مقدار وزن (بین 20 تا 300 کیلوگرم)
    if (weightKg < 0.1 || weightKg > 300.0) {
        qDebug() << "❌ Invalid weight value: " << weightKg;
        emit weightWritten(false, QString("مقدار وزن نامعتبر است: %1 کیلوگرم").arg(weightKg));
        return;
    }

    // فراخوانی متد Kotlin برای نوشتن وزن
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeWeight",
        "(D)Ljava/lang/String;",
        weightKg
        );

    QString status = result.toString();

    // بررسی موفقیت‌آمیز بودن
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    emit weightWritten(success, status);

#else
    qDebug() << "Not Android - Weight write skipped";
    emit weightWritten(false, "Not running on Android");
#endif

}

void Backend::writeBloodPressure(double systolicMmHg, double diastolicMmHg)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << "❌ Activity is invalid!";
        emit bloodPressureWritten(false, "Activity is invalid");
        return;
    }

    // ✅ اعتبارسنجی
    if (systolicMmHg < 80 || systolicMmHg > 200) {
        qDebug() << "❌ Invalid systolic value: " << systolicMmHg;
        emit bloodPressureWritten(false,
                                  QString("مقدار فشار سیستولیک نامعتبر است: %1 mmHg").arg(systolicMmHg));
        return;
    }

    if (diastolicMmHg < 40 || diastolicMmHg > 130) {
        qDebug() << "❌ Invalid diastolic value: " << diastolicMmHg;
        emit bloodPressureWritten(false,
                                  QString("مقدار فشار دیاستولیک نامعتبر است: %1 mmHg").arg(diastolicMmHg));
        return;
    }

    if (systolicMmHg <= diastolicMmHg) {
        qDebug() << "❌ Systolic must be > diastolic";
        emit bloodPressureWritten(false, "فشار سیستولیک باید بزرگتر از دیاستولیک باشد");
        return;
    }

    // ✅ فراخوانی متد Kotlin
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeBloodPressure",
        "(DD)Ljava/lang/String;",
        systolicMmHg,
        diastolicMmHg
        );

    QString status = result.toString();

    bool success = !status.contains("ERROR") && !status.contains("NULL");
    emit bloodPressureWritten(success, status);

#else
    qDebug() << "Not Android - BP write skipped";
    emit bloodPressureWritten(false, "Not running on Android");
#endif
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

    // ✅ Init با دریافت نتیجه
    qDebug() << "🚀 Initializing Health Connect...";

    QJniObject initResult = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "init",
        "(Landroid/content/Context;)Ljava/lang/String;",  // ← حالا String
        activity.object()
        );

    QString status = initResult.toString();

    // ✅ بررسی وضعیت
    if (status == "HC_NOT_INSTALLED") {
        qDebug() << "❌ Health Connect is not installed!";
        qDebug() << "💡 Please install it from Play Store";
        return;
    }

    if (status == "ANDROID_TOO_OLD") {
        qDebug() << "❌ Android version too old (need 9+)";
        return;
    }

    if (status == "HC_UPDATE_REQUIRED") {
        qDebug() << "⚠️ Health Connect needs update";
        // ادامه می‌دهیم چون شاید کار کند
    }

    if (!status.startsWith("INIT_OK") && !status.startsWith("HC_UPDATE_REQUIRED")) {
        qDebug() << "❌ Initialization failed:" << status;
        return;
    }

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
    bpSystolicList.clear();
    bpDiastolicList.clear();

#ifdef Q_OS_ANDROID
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        qDebug() << "❌ Context invalid";
        return;
    }

    // ✅ Step 1: Check permissions
    QJniObject permResult = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "checkPermissions",
        "()Ljava/lang/String;"
        );

    QString permStatus = permResult.toString();
    qDebug() << "🔐" << permStatus;

    // ✅ Step 2: If not granted → request & EXIT
    if (!permStatus.startsWith("ALL_GRANTED")) {
        qDebug() << "⚠️ Requesting permissions...";
        permissionRequest();
        qDebug() << "💡 Grant permissions and press Read again";
        return;  // ← این خط کلیدی است
    }

    qDebug() << "✅ Reading data...";

    // ✅ Step 3: Safe read
    QString status;
    QJniObject result;

    // Height
    result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "readHeight",
        "()Ljava/lang/String;"
        );

    status = result.toString();
    if (status == "SECURITY_ERROR") {
        qDebug() << "❌ Security error (height)";
        return;
    }

    if (!status.startsWith("ERROR") && status != "NO_HEIGHT_DATA") {
        QJsonDocument* document = new QJsonDocument(QJsonDocument::fromJson(status.toUtf8()));
        QJsonArray arr = document->array();
        for(uint32_t i = 0; i < arr.size(); i++) {
            QPointF point;
            QJsonObject obj = arr.at(i).toObject();
            QDateTime dateTime = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
            point.setX(dateTime.toMSecsSinceEpoch());
            point.setY(obj["height_m"].toDouble());
            hList.append(point);
        }
        delete document;
    }

    // Weight
    result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "readWeight",
        "()Ljava/lang/String;"
        );

    status = result.toString();
    if (status == "SECURITY_ERROR") {
        qDebug() << "❌ Security error (weight)";
        return;
    }

    if (!status.startsWith("ERROR") && status != "NO_WEIGHT_DATA") {
        QJsonDocument* document = new QJsonDocument(QJsonDocument::fromJson(status.toUtf8()));
        QJsonArray arr = document->array();
        for(uint32_t i = 0; i < arr.size(); i++) {
            QPointF point;
            QJsonObject obj = arr.at(i).toObject();
            QDateTime dateTime = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
            point.setX(dateTime.toMSecsSinceEpoch());
            point.setY(obj["weight_kg"].toDouble());
            wList.append(point);
        }
        delete document;
    }

    // Blood Pressure
    result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "readBloodPressure",
        "()Ljava/lang/String;"
        );

    status = result.toString();
    if (status == "SECURITY_ERROR") {
        qDebug() << "❌ Security error (BP)";
        return;
    }

    if (!status.contains("NO_BP_DATA") && !status.contains("ERROR")) {
        QJsonDocument* bpDocument = new QJsonDocument(QJsonDocument::fromJson(status.toUtf8()));
        QJsonArray bpArr = bpDocument->array();

        for(qsizetype i = 0; i < bpArr.size(); i++) {
            QJsonObject obj = bpArr.at(i).toObject();
            QDateTime dateTime = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);

            QPointF systolicPoint;
            systolicPoint.setX(dateTime.toMSecsSinceEpoch());
            systolicPoint.setY(obj["systolic_mmhg"].toDouble());
            bpSystolicList.append(systolicPoint);

            QPointF diastolicPoint;
            diastolicPoint.setX(dateTime.toMSecsSinceEpoch());
            diastolicPoint.setY(obj["diastolic_mmhg"].toDouble());
            bpDiastolicList.append(diastolicPoint);
        }

        delete bpDocument;
    }

    emit newDataRead(hList, wList, bpSystolicList, bpDiastolicList);

#else
    qDebug() << "Not Android";
#endif
}
