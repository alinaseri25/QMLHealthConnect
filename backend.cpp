#include "backend.h"

Backend::Backend(QObject *parent)
    : QObject{parent}
{
    //readData();
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

    // بررسی اعتبار مقدار قد
    if (heightMeters < 0.1 || heightMeters > 3) {
        qDebug() << "❌ Invalid height value: " << heightMeters;
        emit heightWritten(false, QString("مقدار قد نامعتبر است: %1 متر").arg(heightMeters));
        return;
    }

    // ✅ دریافت زمان فعلی به فرمت ISO8601
    QString currentTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    // ✅ فراخوانی متد Kotlin با پارامتر زمان
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeHeight",
        "(DLjava/lang/String;)Ljava/lang/String;",  // D=double, String=time
        heightMeters,
        jTime.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if(success)
    {
        status = QString("%1 m").arg(heightMeters);
    }

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

    if (weightKg < 0.1 || weightKg > 300.0) {
        qDebug() << "❌ Invalid weight value: " << weightKg;
        emit weightWritten(false, QString("مقدار وزن نامعتبر است: %1 کیلوگرم").arg(weightKg));
        return;
    }

    // ✅ دریافت زمان فعلی
    QString currentTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeWeight",
        "(DLjava/lang/String;)Ljava/lang/String;",
        weightKg,
        jTime.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if(success)
    {
        status = QString("%1 Kg").arg(weightKg);
    }

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

    // اعتبارسنجی
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

    // ✅ دریافت زمان
    QString currentTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeBloodPressure",
        "(DDLjava/lang/String;)Ljava/lang/String;",
        systolicMmHg,
        diastolicMmHg,
        jTime.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if(success)
    {
        status = QString("%1/%2 mmHg").arg(systolicMmHg).arg(diastolicMmHg);
    }

    emit bloodPressureWritten(success, status);

#else
    qDebug() << "Not Android - BP write skipped";
    emit bloodPressureWritten(false, "Not running on Android");
#endif
}

void Backend::writeHeartRate(int bpm)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << "❌ Activity is invalid!";
        emit heartRateWritten(false, "Activity is invalid");
        return;
    }

    if (bpm < 30 || bpm > 250) {
        qDebug() << "❌ Invalid heart rate value: " << bpm;
        emit heartRateWritten(false,
                              QString("مقدار ضربان قلب نامعتبر است: %1 bpm").arg(bpm));
        return;
    }

    // ✅ دریافت زمان
    QString currentTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeHeartRate",
        "(JLjava/lang/String;)Ljava/lang/String;",  // J=long, String=time
        static_cast<jlong>(bpm),
        jTime.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if(success)
    {
        status = QString("%1 bpm").arg(bpm);
    }

    emit heartRateWritten(success, status);

#else
    qDebug() << "Not Android - Heart rate write skipped";
    emit heartRateWritten(false, "Not running on Android");
#endif
}

void Backend::writeBloodGlucose(double glucoseMgDl, int specimenSource, int mealType, int relationToMeal)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << "❌ Activity is invalid!";
        emit bloodGlucoseWritten(false, "Activity is invalid");
        return;
    }

    // اعتبارسنجی
    if (glucoseMgDl < 20.0 || glucoseMgDl > 600.0) {
        qDebug() << "❌ Invalid glucose value: " << glucoseMgDl;
        emit bloodGlucoseWritten(false,
                                 QString("مقدار قند خون نامعتبر است: %1 mg/dL").arg(glucoseMgDl));
        return;
    }

    if (specimenSource < 0 || specimenSource > 4) {
        emit bloodGlucoseWritten(false, "specimen_source نامعتبر است (باید 0-4 باشد)");
        return;
    }

    if (mealType < 0 || mealType > 3) {
        emit bloodGlucoseWritten(false, "meal_type نامعتبر است (باید 0-3 باشد)");
        return;
    }

    if (relationToMeal < 0 || relationToMeal > 4) {
        emit bloodGlucoseWritten(false, "relation_to_meal نامعتبر است (باید 0-4 باشد)");
        return;
    }

    // ✅ دریافت زمان
    QString currentTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeBloodGlucose",
        "(DIIILjava/lang/String;)Ljava/lang/String;",
        glucoseMgDl,
        specimenSource,
        mealType,
        relationToMeal,
        jTime.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if(success)
    {
        status = QString("%1 mg/dl").arg(glucoseMgDl);
    }

    emit bloodGlucoseWritten(success, status);

#else
    qDebug() << "Not Android - Blood glucose write skipped";
    emit bloodGlucoseWritten(false, "Not running on Android");
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
    heartRateList.clear();
    bloodGlucoseList.clear();

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
        return;
    }

    qDebug() << "✅ Reading data...";

    // ✅ ساخت بازه زمانی: یک ماه اخیر تا الان
    QString startTime = isoStringMonthsAgo(1);
    QString endTime   = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    qDebug() << "📅 Time range:" << startTime << "→" << endTime;

    QString status;
    QJniObject result;

    // ─────────────────────────────────────────
    // Height
    // ─────────────────────────────────────────
    {
        QJniObject jStart = QJniObject::fromString(startTime);
        QJniObject jEnd   = QJniObject::fromString(endTime);

        result = QJniObject::callStaticObjectMethod(
            "org/verya/QMLHealthConnect/HealthBridge",
            "readHeight",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            jStart.object<jstring>(),
            jEnd.object<jstring>()
            );

        status = result.toString();
        qDebug() << "📏 Height status:" << status.left(80);

        if (status == "SECURITY_ERROR") {
            qDebug() << "❌ Security error (height)";
            return;
        }

        if (!status.startsWith("ERROR") && status != "NO_HEIGHT_DATA") {
            QJsonDocument doc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = doc.array();
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                hList.append(QPointF(dt.toMSecsSinceEpoch(), obj["height_m"].toDouble()));
            }
        }
    }

    // ─────────────────────────────────────────
    // Weight
    // ─────────────────────────────────────────
    {
        QJniObject jStart = QJniObject::fromString(startTime);
        QJniObject jEnd   = QJniObject::fromString(endTime);

        result = QJniObject::callStaticObjectMethod(
            "org/verya/QMLHealthConnect/HealthBridge",
            "readWeight",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            jStart.object<jstring>(),
            jEnd.object<jstring>()
            );

        status = result.toString();
        qDebug() << "⚖️ Weight status:" << status.left(80);

        if (status == "SECURITY_ERROR") {
            qDebug() << "❌ Security error (weight)";
            return;
        }

        if (!status.startsWith("ERROR") && status != "NO_WEIGHT_DATA") {
            QJsonDocument doc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = doc.array();
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                wList.append(QPointF(dt.toMSecsSinceEpoch(), obj["weight_kg"].toDouble()));
            }
        }
    }

    // ─────────────────────────────────────────
    // Blood Pressure
    // ─────────────────────────────────────────
    {
        QJniObject jStart = QJniObject::fromString(startTime);
        QJniObject jEnd   = QJniObject::fromString(endTime);

        result = QJniObject::callStaticObjectMethod(
            "org/verya/QMLHealthConnect/HealthBridge",
            "readBloodPressure",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            jStart.object<jstring>(),
            jEnd.object<jstring>()
            );

        status = result.toString();
        qDebug() << "🩺 BP status:" << status.left(80);

        if (status == "SECURITY_ERROR") {
            qDebug() << "❌ Security error (BP)";
            return;
        }

        if (!status.contains("NO_BP_DATA") && !status.contains("ERROR")) {
            QJsonDocument doc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = doc.array();
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                qint64 ms = dt.toMSecsSinceEpoch();

                bpSystolicList.append(QPointF(ms, obj["systolic"].toDouble()));
                bpDiastolicList.append(QPointF(ms, obj["diastolic"].toDouble()));
                //qDebug() << QString("systolic_mmhg : %1 -- diastolic_mmhg : %2").arg(bpSystolicList.end()->y()).arg(bpDiastolicList.end()->y());
            }
        }
    }

    // ─────────────────────────────────────────
    // Heart Rate
    // ─────────────────────────────────────────
    {
        QJniObject jStart = QJniObject::fromString(startTime);
        QJniObject jEnd   = QJniObject::fromString(endTime);

        result = QJniObject::callStaticObjectMethod(
            "org/verya/QMLHealthConnect/HealthBridge",
            "readHeartRate",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            jStart.object<jstring>(),
            jEnd.object<jstring>()
            );

        status = result.toString();
        qDebug() << "❤️ Heart Rate status:" << status.left(80);

        if (status == "SECURITY_ERROR") {
            qDebug() << "❌ Security error (heart rate)";
            return;
        }

        if (!status.startsWith("ERROR") && status != "NO_HEART_RATE_DATA") {
            QJsonDocument doc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = doc.array();
            // qDebug() << "💓 Processing" << arr.size() << "heart rate records";
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                heartRateList.append(QPointF(dt.toMSecsSinceEpoch(), obj["bpm"].toDouble()));
            }
        }
    }

    // ─────────────────────────────────────────
    // Blood Glucose
    // ─────────────────────────────────────────
    {
        QJniObject jStart = QJniObject::fromString(startTime);
        QJniObject jEnd   = QJniObject::fromString(endTime);

        result = QJniObject::callStaticObjectMethod(
            "org/verya/QMLHealthConnect/HealthBridge",
            "readBloodGlucose",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            jStart.object<jstring>(),
            jEnd.object<jstring>()
            );

        status = result.toString();
        qDebug() << "🩸 Glucose status:" << status.left(80);

        if (status == "SECURITY_ERROR") {
            qDebug() << "❌ Security error (blood glucose)";
            return;
        }

        if (!status.startsWith("ERROR") && status != "NO_BLOOD_GLUCOSE_DATA") {
            QJsonDocument doc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = doc.array();
            // qDebug() << "🩸 Processing" << arr.size() << "blood glucose records";
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                bloodGlucoseList.append(QPointF(dt.toMSecsSinceEpoch(), obj["glucose_mg_dl"].toDouble()));
            }
        }
    }

    emit newDataRead(hList, wList, bpSystolicList, bpDiastolicList, heartRateList, bloodGlucoseList);

#else
    qDebug() << "Not Android";
#endif
}

QString Backend::isoStringMonthsAgo(int months)
{
    QDateTime now = QDateTime::currentDateTimeUtc();
    QDateTime past = now.addMonths(-months);
    // فرمت ISO8601 که Kotlin می‌فهمد
    return past.toString(Qt::ISODateWithMs);
}
