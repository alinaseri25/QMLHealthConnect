#include "backend.h"

static Backend* g_mainWindowInstance = nullptr;

#ifdef ANDROID

extern "C"
    JNIEXPORT void JNICALL
        Java_org_verya_QMLHealthConnect_TestBridge_nativeOnPermissionResult
    (JNIEnv *env, jclass /*clazz*/, jstring msg)
{
    if (!g_mainWindowInstance)
        return;

    // تبدیل jstring به QString در همان thread JNI
    QString jsonStr = QJniObject(msg).toString();

    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    QJsonObject root = doc.object();
    QJsonArray perms = root["results"].toArray();

    for (const QJsonValue &v : perms) {
        QJsonObject o = v.toObject();
        QString permission = o["permission"].toString();
        bool granted = o["granted"].toBool();
        qDebug() << permission << (granted ? "✅" : "❌");
    }

    // QMetaObject::invokeMethod(g_mainWindowInstance, [=]() {
    //     QString str = (qMsg == "start") ? "Play" : "Pause";

    //     qDebug() << "str:" << str << "--msg:" << qMsg;

    //     g_mainWindowInstance->onPlayPause(str);
    // }, Qt::QueuedConnection);
}

#endif

Backend::Backend(QObject *parent)
    : QObject{parent}
{
    g_mainWindowInstance = this;
#ifdef ANDROID
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return;

    QJniObject::callStaticMethod<void>(
        "org/verya/DezliQC/MainActivity",
        "manageScreenAndWakeLock",
        "(Landroid/content/Context;ZZ)V",
        context.object(),
        (jboolean)true,  // screenAlwaysOn
        (jboolean)true    // wakeLock
        );

    QJniObject::callStaticMethod<void>(
        "org/verya/DezliQC/MainActivity",
        "setDimTimeoutFromQt",
        "(J)V",
        0
        );
#endif
    loadAvailablePath();
}

void Backend::onQmlReady()
{
    QStringList permissions = { "android.permission.health.READ_HEIGHT",
                                "android.permission.health.WRITE_HEIGHT",
                                "android.permission.health.READ_WEIGHT",
                                "android.permission.health.WRITE_WEIGHT",
                                "android.permission.health.READ_BLOOD_PRESSURE",
                                "android.permission.health.WRITE_BLOOD_PRESSURE",
                                "android.permission.health.READ_HEART_RATE",
                                "android.permission.health.WRITE_HEART_RATE",
                                "android.permission.health.READ_BLOOD_GLUCOSE",
                                "android.permission.health.WRITE_BLOOD_GLUCOSE",
                                "android.permission.health.READ_OXYGEN_SATURATION",
                                "android.permission.health.WRITE_OXYGEN_SATURATION",
                                "android.permission.health.READ_MENSTRUATION",
                                "android.permission.health.WRITE_MENSTRUATION"};
    askForPermission(permissions,12);
    checkPermissions();
    loadPeriodState();
}

void Backend::onUpdateRequest(bool height, bool weight, bool bp, bool bg, bool hr, bool spo2, QDateTime startFrom, QDateTime endTo)
{
    hList.clear();
    wList.clear();
    bpSystolicList.clear();
    bpDiastolicList.clear();
    heartRateList.clear();
    bloodGlucoseList.clear();
    oxygenSaturationList.clear();

#ifdef Q_OS_ANDROID
    checkPermissions();

    qDebug() << "✅ Reading data...";

    // ✅ ساخت بازه زمانی: یک ماه اخیر تا الان
    QString startTime = startFrom.toUTC().toString(Qt::ISODateWithMs); //isoStringMonthsAgo(1);
    QString endTime   = endTo.toUTC().toString(Qt::ISODateWithMs); //QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    qDebug() << "📅 Time range:" << startTime << " or " << startFrom.toString("yyyy/MM/dd hh:mm:ss") << " → " << endTime << endTo.toString("yyyy/MM/dd hh:mm:ss");

    if(height)
    {
        readHeight(startTime,endTime);
    }
    if(weight)
    {
        readWeight(startTime,endTime);
    }
    if(bp)
    {
        readBP(startTime,endTime);
    }
    if(bg)
    {
        readBG(startTime,endTime);
    }
    if(hr)
    {
        readHR(startTime,endTime);
    }
    if(spo2)
    {
        readOxygenSaturation(startTime, endTime);
    }

    emit newDataRead(hList, wList, bpSystolicList, bpDiastolicList,
                     heartRateList, bloodGlucoseList, oxygenSaturationList);

    readMenstruationData(startTime,endTime);


    QString menstrJsonStr;

    if (periodJsonDoc.isNull() || !periodJsonDoc.isObject()) {
        menstrJsonStr = "{\"periods\":[],\"flows\":[]}";
    } else {
        QJsonObject root     = periodJsonDoc.object();
        QJsonArray  inPeriods = root["periods"].toArray();
        QJsonArray  inFlows   = root["flows"].toArray();

        QJsonArray outPeriods;
        for (const MenstruationPeriod &p : periodList) {
            QJsonObject out;
            out["startMs"] = p.start.toMSecsSinceEpoch();
            out["endMs"]   = p.end.toMSecsSinceEpoch();
            outPeriods.append(out);
        }

        QJsonArray outFlows;
        for (const MenstruationFlow &f : periodFlowList) {
            QJsonObject out;
            out["timeMs"] = f.time.toMSecsSinceEpoch();
            out["level"]  = f.level;
            outFlows.append(out);
        }

        QJsonObject finalRoot;
        finalRoot["periods"] = outPeriods;
        finalRoot["flows"]   = outFlows;
        menstrJsonStr = QJsonDocument(finalRoot).toJson(QJsonDocument::Compact);
    }

    qDebug() << "📤 menstruation JSON ready:" << menstrJsonStr.left(200);

    // ✅ فقط emit داخل تایمر - jsonStr کپی شده در lambda
    QTimer::singleShot(100, this, [this, menstrJsonStr]() {
        emit menstruationDataRead(menstrJsonStr);
    });
#else
    qDebug() << "Not Android";
#endif
}

void Backend::onExportRequest(bool height, bool weight, bool bp, bool bg, bool hr, bool spo2)
{
#ifdef Q_OS_ANDROID
    QXlsx::Document xlsx;
    //xlsx.deleteSheet(xlsx.sheetNames().first());
    if(height)
    {
        exportHeight(&xlsx);
    }
    if(weight)
    {
        exportWeight(&xlsx);
    }
    if(bp)
    {
        exportBP(&xlsx);
    }
    if(bg)
    {
        exportBG(&xlsx);
    }
    if(hr)
    {
        exportHR(&xlsx);
    }
    if(spo2)
    {
        exportOxygenSaturation(&xlsx);
    }
    if ((periodFlowList.length() > 0) || (periodList.length() > 0))
    {
        exportMenstruationData(&xlsx);
    }

    QString excelFileName = QDateTime::currentDateTime().toString(QString("yyyy-MM-dd_hh:mm:ss"));
    QString excelPath = QString("%1/%2.xlsx").arg(path, excelFileName);

    bool success = xlsx.saveAs(excelPath);
    QString message;

    if(success)
    {
        message = QString("Excel file prepaired.\n");
        success = copyToDownloads(excelPath,excelFileName);
        if(success)
        {
            message.append(QString("File %1 Saved to Downloads").arg(excelFileName));
        }
    }
    else
    {
        message = QString("Excel file Cannot write on \"%1\"").arg(excelPath);
    }

    emit exportCompleted(success,message);
#else
    qDebug() << "Not Android";
#endif
}

void Backend::writeHeight(double heightMeters,QDateTime dt)
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
    QString currentTime = dt.toUTC().toString(Qt::ISODateWithMs);
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

void Backend::writeWeight(double weightKg,QDateTime dt)
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
    QString currentTime = dt.toUTC().toString(Qt::ISODateWithMs);
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

void Backend::writeBloodPressure(double systolicMmHg, double diastolicMmHg, QDateTime dt)
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
    QString currentTime = dt.toUTC().toString(Qt::ISODateWithMs);
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

void Backend::writeHeartRate(int bpm,QDateTime dt)
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
    QString currentTime = dt.toUTC().toString(Qt::ISODateWithMs);
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

void Backend::writeBloodGlucose(double glucoseMgDl, int specimenSource, int mealType, int relationToMeal, QDateTime dt)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        emit bloodGlucoseWritten(false, "Activity is invalid");
        return;
    }

    if (glucoseMgDl < 20.0 || glucoseMgDl > 600.0) {
        emit bloodGlucoseWritten(false, QString("مقدار قند خون نامعتبر: %1 mg/dL").arg(glucoseMgDl));
        return;
    }

    // ✅ UTC — مثل writeHeight
    QString currentTime = dt.toUTC().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    // ✅ اصلاح: (D, String, I, I, I) — String دوم میاد نه پنجم
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeBloodGlucose",
        "(DLjava/lang/String;III)Ljava/lang/String;",
        glucoseMgDl,
        jTime.object<jstring>(),
        (jint)specimenSource,
        (jint)mealType,
        (jint)relationToMeal
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");
    if (success) status = QString("%1 mg/dl").arg(glucoseMgDl);
    emit bloodGlucoseWritten(success, status);

#else
    qDebug() << "Not Android";
    emit bloodGlucoseWritten(false, "Not running on Android");
#endif
}

void Backend::writeOxygenSaturation(double percentage, QDateTime dt)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();

    if (!activity.isValid()) {
        qDebug() << "❌ Activity is invalid!";
        emit oxygenSaturationWritten(false, "Activity is invalid");
        return;
    }

    // ✅ اعتبارسنجی مقدار
    if (percentage < 50.0 || percentage > 100.0) {
        qDebug() << "❌ Invalid SpO2 value:" << percentage;
        emit oxygenSaturationWritten(false,
                                     QString("مقدار اشباع اکسیژن نامعتبر است: %1%").arg(percentage));
        return;
    }

    // ⚠️ هشدار برای مقادیر پایین
    if (percentage < 90.0) {
        qWarning() << "⚠️ Warning: Low SpO2 value:" << percentage << "%";
    }

    // ✅ دریافت زمان فعلی به فرمت ISO8601
    QString currentTime = dt.toUTC().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(currentTime);

    // ✅ فراخوانی متد Kotlin
    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeOxygenSaturation",
        "(DLjava/lang/String;)Ljava/lang/String;",  // D=double, String=time
        percentage,
        jTime.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if (success) {
        status = QString("%1 %%").arg(percentage, 0, 'f', 1); // یک رقم اعشار

        // ✅ افزودن برچسب وضعیت
        QString condition;
        if (percentage >= 95.0) {
            condition = " (نرمال ✅)";
        } else if (percentage >= 90.0) {
            condition = " (قابل توجه ⚠️)";
        } else {
            condition = " (خطرناک ⛔)";
        }
        status += condition;
    }

    qDebug() << "🫁 SpO2 write result:" << status;
    emit oxygenSaturationWritten(success, status);

#else
    qDebug() << "Not Android - Oxygen saturation write skipped";
    emit oxygenSaturationWritten(false, "Not running on Android");
#endif
}

void Backend::writeMenstruationFlow(int flowLevel, QDateTime dt)
{
    // اعتبارسنجی
    if (flowLevel < 1 || flowLevel > 3) {
        qDebug() << "❌ Invalid flow level:" << flowLevel;
        emit menstruationFlowWritten(false,
                                     QString("سطح خونریزی نامعتبر است: %1 (باید ۱ تا ۳ باشد)").arg(flowLevel));
        return;
    }

    // اگه اولین ثبت این دوره‌ست → startTime رو ذخیره کن
    if (!periodActive) {
        periodActive       = true;
        currentPeriodStart = dt;
        savePeriodState();
        qDebug() << "🩸 Period started at:" << dt.toString("yyyy/MM/dd");
    }

#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        emit menstruationFlowWritten(false, "Activity is invalid");
        return;
    }

    QString timeIso = dt.toUTC().toString(Qt::ISODateWithMs);
    QJniObject jTime = QJniObject::fromString(timeIso);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeMenstruationFlow",
        "(Ljava/lang/String;I)Ljava/lang/String;",
        jTime.object<jstring>(),
        (jint)flowLevel
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if (success) {
        static const QStringList levelNames = {"", "سبک", "متوسط", "سنگین"};
        status = QString("شدت %1 برای %2 ثبت شد")
                     .arg(levelNames.value(flowLevel))
                     .arg(dt.toString("yyyy/MM/dd hh:mm:ss"));
    }

    emit menstruationFlowWritten(success, status);

#else
    qDebug() << "Not Android - MenstruationFlow write skipped. Level:" << flowLevel;
    emit menstruationFlowWritten(true,
                                 QString("(Desktop) شدت %1 برای %2 ثبت شد")
                                     .arg(flowLevel)
                                     .arg(dt.toString("yyyy/MM/dd")));
#endif
}

void Backend::writeMenstruationPeriod(QDateTime endTime)
{
    // بررسی اینکه آیا دوره فعالی هست
    if (!periodActive || !currentPeriodStart.isValid()) {
        emit menstruationPeriodWritten(false,
                                       "هیچ دوره فعالی برای پایان دادن وجود ندارد");
        return;
    }

    // اعتبارسنجی بازه
    if (endTime < currentPeriodStart) {
        emit menstruationPeriodWritten(false,
                                       "تاریخ پایان نمی‌تواند قبل از تاریخ شروع باشد");
        return;
    }

    qint64 durationDays = currentPeriodStart.daysTo(endTime);
    if (durationDays > 15) {
        emit menstruationPeriodWritten(false,
                                       QString("طول دوره نامعتبر است: %1 روز (حداکثر ۱۵ روز)").arg(durationDays));
        return;
    }

#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        emit menstruationPeriodWritten(false, "Activity is invalid");
        return;
    }

    qDebug() << "start : " << currentPeriodStart.toString("yyyy/MM/dd hh:mm:ss") << " --- end : " << endTime.toString("yyyy/MM/dd hh:mm:ss");

    QString startIso = currentPeriodStart.toUTC().toString(Qt::ISODateWithMs);
    QString endIso   = endTime.toUTC().toString(Qt::ISODateWithMs);

    QJniObject jStart = QJniObject::fromString(startIso);
    QJniObject jEnd   = QJniObject::fromString(endIso);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "writeMenstruationPeriod",
        "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
        jStart.object<jstring>(),
        jEnd.object<jstring>()
        );

    QString status = result.toString();
    bool success = !status.contains("ERROR") && !status.contains("NULL");

    if (success) {
        // ── پاک‌سازی state ──────────────────────────────────
        periodActive = false;
        currentPeriodStart = QDateTime();
        savePeriodState();
        emit periodStateChanged(periodActive);

        status = QString("دوره از %1 تا %2 (%3 روز) ثبت شد")
                     .arg(currentPeriodStart.toString("yyyy/MM/dd"))
                     .arg(endTime.toString("yyyy/MM/dd"))
                     .arg(durationDays + 1);
    }

    emit menstruationPeriodWritten(success, status);

#else
    QString startStr = currentPeriodStart.toString("yyyy/MM/dd");
    periodActive = false;
    currentPeriodStart = QDateTime();
    savePeriodState();
    emit periodStateChanged(periodActive);

    qDebug() << "Not Android - MenstruationPeriod write skipped."
             << "Start:" << startStr
             << "End:"   << endTime.toString("yyyy/MM/dd");

    emit menstruationPeriodWritten(true,
                                   QString("(Desktop) دوره از %1 تا %2 (%3 روز) شبیه‌سازی شد")
                                       .arg(startStr)
                                       .arg(endTime.toString("yyyy/MM/dd"))
                                       .arg(durationDays + 1));
#endif
}

void Backend::readMenstruationData(QString startFrom, QString endTo)
{
    periodList.clear();
    periodFlowList.clear();

#ifdef Q_OS_ANDROID
    QJniObject jStart = QJniObject::fromString(startFrom);
    QJniObject jEnd   = QJniObject::fromString(endTo);

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "readMenstruationData",
        "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
        jStart.object<jstring>(),
        jEnd.object<jstring>()
        );

    QString jsonStr = result.toString();

    if (jsonStr.startsWith("ERROR") ||
        jsonStr == "CLIENT_NULL"    ||
        jsonStr == "NO_MENSTRUATION_DATA") {
        qDebug() << "⚠️ readMenstruationData:" << jsonStr;
        // ❌ اینجا emit نکن - بذار onUpdateRequest بعد از newDataRead emit کنه
        return;
    }

    periodJsonDoc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (!periodJsonDoc.isObject()) {
        qDebug() << "❌ readMenstruationData: invalid JSON";
        return;
    }

    QJsonObject root = periodJsonDoc.object();

    // ── periods ──────────────────────────────────────────────
    QJsonArray periods = root["periods"].toArray();
    for (const QJsonValue &v : periods) {
        QJsonObject obj = v.toObject();
        MenstruationPeriod p;

        // ✅ اصلاح: اضافه کردن Qt::UTC صریح
        QString startStr = obj["start"].toString();
        QString endStr   = obj["end"].toString();

        p.start = QDateTime::fromString(startStr, Qt::ISODateWithMs);
        p.end   = QDateTime::fromString(endStr,   Qt::ISODateWithMs);

        // اگر timeSpec درست تنظیم نشده، دستی UTC بگذار
        if (p.start.timeSpec() != Qt::UTC) {
            p.start.setTimeSpec(Qt::UTC);
        }
        if (p.end.timeSpec() != Qt::UTC) {
            p.end.setTimeSpec(Qt::UTC);
        }

        qDebug() << "[readMenst] period start raw:" << startStr;
        qDebug() << "[readMenst] period start parsed:" << p.start.toString(Qt::ISODateWithMs);
        qDebug() << "[readMenst] period start ms:" << p.start.toMSecsSinceEpoch();
        qDebug() << "[readMenst] period start timeSpec:" << p.start.timeSpec();

        if (p.start.isValid() && p.end.isValid()) {
            periodList.append(p);
        } else {
            qDebug() << "❌ Invalid period skipped:" << startStr << endStr;
        }
    }

    // ── flows ─────────────────────────────────────────────────
    QJsonArray flows = root["flows"].toArray();
    for (const QJsonValue &v : flows) {
        QJsonObject obj = v.toObject();
        MenstruationFlow f;

        QString timeStr = obj["time"].toString();
        f.time  = QDateTime::fromString(timeStr, Qt::ISODateWithMs);

        if (f.time.timeSpec() != Qt::UTC) {
            f.time.setTimeSpec(Qt::UTC);
        }

        f.level = obj["level"].toInt(0);
        if (f.time.isValid()) {
            periodFlowList.append(f);
        }
    }

    qDebug() << "✅ Menstruation read:"
             << periodList.size() << "periods,"
             << periodFlowList.size() << "flows";

    // ✅ اینجا emit نکن! - onUpdateRequest این کار را می‌کند
#else
    qDebug() << "Not Android - readMenstruationData skipped";
#endif
}

void Backend::exportMenstruationData(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ══════════════════════════════════════════════════════════
    // Sheet 1 — دوره‌های قاعدگی (Menstruation Periods)
    // ══════════════════════════════════════════════════════════
    xlsx->addSheet("Menstruation Periods");
    xlsx->selectSheet("Menstruation Periods");

    // ── فرمت هدر ──────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#D5006D"));   // صورتی تیره
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#FCE4EC"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── ستون‌ها ────────────────────────────────────────────────
    xlsx->write(1, 1, "Start Date",    headerFormat);
    xlsx->write(1, 2, "Start Time",    headerFormat);
    xlsx->write(1, 3, "End Date",      headerFormat);
    xlsx->write(1, 4, "End Time",      headerFormat);
    xlsx->write(1, 5, "Duration (days)", headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 14);
    xlsx->setColumnWidth(4, 12);
    xlsx->setColumnWidth(5, 16);

    // ── داده‌ها ────────────────────────────────────────────────
    for (int i = 0; i < periodList.size(); i++) {
        const MenstruationPeriod &p = periodList.at(i);
        int row = i + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        QDateTime localStart = p.start.toLocalTime();
        QDateTime localEnd   = p.end.toLocalTime();

        int durationDays = static_cast<int>(p.start.daysTo(p.end)) + 1;

        xlsx->write(row, 1, localStart.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, localStart.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, localEnd.toString("yyyy-MM-dd"),   rowFmt);
        xlsx->write(row, 4, localEnd.toString("hh:mm:ss"),     rowFmt);
        xlsx->write(row, 5, durationDays,                      rowFmt);
    }

    // ══════════════════════════════════════════════════════════
    // Sheet 2 — جریان خونریزی (Menstruation Flow)
    // ══════════════════════════════════════════════════════════
    xlsx->addSheet("Menstruation Flow");
    xlsx->selectSheet("Menstruation Flow");

    // ── فرمت هدر ──────────────────────────────────────────────
    QXlsx::Format flowHeaderFormat;
    flowHeaderFormat.setFontBold(true);
    flowHeaderFormat.setPatternBackgroundColor(QColor("#AD1457"));  // صورتی خیلی تیره
    flowHeaderFormat.setFontColor(Qt::white);
    flowHeaderFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت‌های ردیف بر اساس سطح خونریزی ───────────────────
    QXlsx::Format lightFormat;   // سبک
    lightFormat.setPatternBackgroundColor(QColor("#F8BBD0"));
    lightFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format mediumFormat;  // متوسط
    mediumFormat.setPatternBackgroundColor(QColor("#F48FB1"));
    mediumFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format heavyFormat;   // سنگین
    heavyFormat.setPatternBackgroundColor(QColor("#E91E63"));
    heavyFormat.setFontColor(Qt::white);
    heavyFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format unknownFormat; // نامشخص
    unknownFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── ستون‌ها ────────────────────────────────────────────────
    xlsx->write(1, 1, "Date",         flowHeaderFormat);
    xlsx->write(1, 2, "Time",         flowHeaderFormat);
    xlsx->write(1, 3, "Flow Level",   flowHeaderFormat);
    xlsx->write(1, 4, "Description",  flowHeaderFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 12);
    xlsx->setColumnWidth(4, 16);

    // ── داده‌ها ────────────────────────────────────────────────
    static const QStringList levelLabels = {"Unknown", "Light", "Medium", "Heavy"};
    static const QStringList levelEmoji  = {"❓",       "🩸",    "🩸🩸",  "🩸🩸🩸"};

    for (int i = 0; i < periodFlowList.size(); i++) {
        const MenstruationFlow &f = periodFlowList.at(i);
        int row = i + 2;

        QDateTime localTime = f.time.toLocalTime();

        // انتخاب فرمت بر اساس سطح
        QXlsx::Format *rowFmt = &unknownFormat;
        if      (f.level == 1) rowFmt = &lightFormat;
        else if (f.level == 2) rowFmt = &mediumFormat;
        else if (f.level == 3) rowFmt = &heavyFormat;

        int safeLevel = (f.level >= 0 && f.level <= 3) ? f.level : 0;

        xlsx->write(row, 1, localTime.toString("yyyy-MM-dd"),          *rowFmt);
        xlsx->write(row, 2, localTime.toString("hh:mm:ss"),            *rowFmt);
        xlsx->write(row, 3, f.level,                                   *rowFmt);
        xlsx->write(row, 4, levelLabels.at(safeLevel),                 *rowFmt);
    }
#else
    qDebug() << "Not Android - readMenstruationData skipped";
#endif
}

bool Backend::copyToDownloads(const QString &srcPath, const QString &fileName)
{
#ifdef Q_OS_ANDROID
    QJniEnvironment env;

    // ─── ContentValues ───
    QJniObject contentValues("android/content/ContentValues");

    contentValues.callMethod<void>("put",
                                   "(Ljava/lang/String;Ljava/lang/String;)V",
                                   QJniObject::fromString("_display_name").object<jstring>(),
                                   QJniObject::fromString(fileName).object<jstring>());

    contentValues.callMethod<void>("put",
                                   "(Ljava/lang/String;Ljava/lang/String;)V",
                                   QJniObject::fromString("mime_type").object<jstring>(),
                                   QJniObject::fromString(
                                       "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                                       ).object<jstring>());

    // Android 10+ — مسیر داخل Downloads
    contentValues.callMethod<void>("put",
                                   "(Ljava/lang/String;Ljava/lang/String;)V",
                                   QJniObject::fromString("relative_path").object<jstring>(),
                                   QJniObject::fromString("Download/").object<jstring>());

    // ─── ContentResolver ───
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");

    QJniObject context = activity.callObjectMethod(
        "getApplicationContext",
        "()Landroid/content/Context;");

    QJniObject resolver = context.callObjectMethod(
        "getContentResolver",
        "()Landroid/content/ContentResolver;");

    // ─── MediaStore Downloads URI ───
    QJniObject downloadsUri = QJniObject::callStaticObjectMethod(
        "android/provider/MediaStore$Downloads",
        "getContentUri",
        "(Ljava/lang/String;)Landroid/net/Uri;",
        QJniObject::fromString("external").object<jstring>());

    // ─── Insert و دریافت URI فایل مقصد ───
    QJniObject destUri = resolver.callObjectMethod(
        "insert",
        "(Landroid/net/Uri;Landroid/content/ContentValues;)Landroid/net/Uri;",
        downloadsUri.object(),
        contentValues.object());

    if (!destUri.isValid()) {
        qWarning() << "MediaStore insert failed";
        return false;
    }

    // ─── خواندن فایل منبع ───
    QFile srcFile(srcPath);
    if (!srcFile.open(QIODevice::ReadOnly)) {
        qWarning() << "Cannot open source file:" << srcPath;
        return false;
    }
    QByteArray data = srcFile.readAll();
    srcFile.close();

    // ─── نوشتن به OutputStream ───
    QJniObject outputStream = resolver.callObjectMethod(
        "openOutputStream",
        "(Landroid/net/Uri;)Ljava/io/OutputStream;",
        destUri.object());

    if (!outputStream.isValid()) {
        qWarning() << "Cannot open OutputStream";
        return false;
    }

    jbyteArray byteArray = env->NewByteArray(data.size());
    env->SetByteArrayRegion(byteArray, 0, data.size(),
                            reinterpret_cast<const jbyte*>(data.constData()));

    outputStream.callMethod<void>("write", "([B)V", byteArray);
    outputStream.callMethod<void>("flush");
    outputStream.callMethod<void>("close");
    env->DeleteLocalRef(byteArray);

    qDebug() << "✅ File saved to Downloads:" << fileName;
    return true;

#else
    Q_UNUSED(srcPath)
    Q_UNUSED(fileName)
    return false;
#endif
}

void Backend::loadAvailablePath()
{
#ifdef Q_OS_ANDROID
    path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(path);
#else
    QStringList systemEnvironment = QProcess::systemEnvironment();
    foreach (QString Str, systemEnvironment) {
        //QMessageBox::about(this,QString("System Environment"),QString("Data : %1").arg(Str));
        if(Str.contains("EXTERNAL_STORAGE="))
        {
            Str.remove("EXTERNAL_STORAGE=");
            path = Str;
            break;
        }
    }
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

bool Backend::checkPermissions()
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        //emit permissionsChecked(false, "Activity is invalid");
        return false;
    }

    QJniObject result = QJniObject::callStaticObjectMethod(
        "org/verya/QMLHealthConnect/HealthBridge",
        "checkPermissions",
        "()Ljava/lang/String;"
        );

    QString jsonStr = result.toString();

    // ── پارس JSON جدید ──────────────────────────────────────────
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());

    if (doc.isNull() || !doc.isObject()) {
        // fallback — اگه JSON پارس نشد
        qDebug() << "⚠️ checkPermissions: invalid JSON:" << jsonStr;
        //emit permissionsChecked(false, jsonStr);
        return false;
    }

    QJsonObject obj = doc.object();

    // ── بررسی خطا ───────────────────────────────────────────────
    if (obj.contains("error")) {
        QString errMsg = obj["error"].toString();
        qDebug() << "❌ checkPermissions error:" << errMsg;
        //emit permissionsChecked(false, errMsg);
        return false;
    }

    // ── خواندن وضعیت کلی ────────────────────────────────────────
    bool allGranted   = obj["allGranted"].toBool(false);
    int  grantedCount = obj["grantedCount"].toInt(0);
    int  totalCount   = obj["totalCount"].toInt(0);

    // ── لاگ جزئیات هر permission ────────────────────────────────
    QJsonArray perms = obj["permissions"].toArray();
    QStringList missing;

    for (const QJsonValue &val : perms) {
        QJsonObject p    = val.toObject();
        QString name     = p["name"].toString();
        bool    isGranted = p["granted"].toBool(false);

        if (!isGranted) {
            missing.append(name);
        }
        qDebug() << (isGranted ? "✅" : "❌") << name;
    }

    if (!missing.isEmpty()) {
        qDebug() << "⚠️ Missing permissions:" << missing.join(", ");
    }

    QString statusMsg = allGranted
                            ? QString("همه دسترسی‌ها فعال هستند (%1/%2)")
                                  .arg(grantedCount).arg(totalCount)
                            : QString("برخی دسترسی‌ها موجود نیستند (%1/%2): %3")
                                  .arg(grantedCount).arg(totalCount)
                                  .arg(missing.join("، "));

    qDebug() << "🔐 Permissions:" << statusMsg;

    // ── ارسال JSON کامل به QML از طریق سیگنال ───────────────────
    emit permissionsState(allGranted, statusMsg);  // ← JSON کامل

#else
    qDebug() << "Not Android";
#endif
    return true;
}

void Backend::readHeight(QString startTime,QString endTime)
{
#ifdef Q_OS_ANDROID
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
            heightJsonDoc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = heightJsonDoc.array();
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                hList.append(QPointF(dt.toMSecsSinceEpoch(), obj["height_m"].toDouble()));
            }
        }
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::exportHeight(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ── Sheet ────────────────────────────────────────────────
    xlsx->addSheet("Height Data");
    xlsx->selectSheet("Height Data");

    // ── فرمت هدر ─────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#1565C0"));
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#E3F2FD"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── هدر ستون‌ها ───────────────────────────────────────────
    xlsx->write(1, 1, "Date",        headerFormat);
    xlsx->write(1, 2, "Time",        headerFormat);
    xlsx->write(1, 3, "Height (cm)", headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 14);

    // ── داده‌ها ────────────────────────────────────────────────
    QJsonArray arr = heightJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(
                           obj["time"].toString(), Qt::ISODate
                           ).toLocalTime();
        double heightCm = obj["height_m"].toDouble() * 100.0;
        int row = static_cast<int>(i) + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        xlsx->write(row, 1, dt.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, dt.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, heightCm,                  rowFmt);
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::readWeight(QString startTime, QString endTime)
{
#ifdef Q_OS_ANDROID
    QString status;
    QJniObject result;
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
            weightJsonDoc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = weightJsonDoc.array();
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                wList.append(QPointF(dt.toMSecsSinceEpoch(), obj["weight_kg"].toDouble()));
            }
        }
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::exportWeight(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ── Sheet ────────────────────────────────────────────────
    xlsx->addSheet("Weight Data");
    xlsx->selectSheet("Weight Data");

    // ── فرمت هدر ─────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#2E7D32"));
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#E8F5E9"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── هدر ستون‌ها ───────────────────────────────────────────
    xlsx->write(1, 1, "Date",        headerFormat);
    xlsx->write(1, 2, "Time",        headerFormat);
    xlsx->write(1, 3, "Weight (kg)", headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 14);

    // ── داده‌ها ────────────────────────────────────────────────
    QJsonArray arr = weightJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(
                           obj["time"].toString(), Qt::ISODate
                           ).toLocalTime();
        double weightKg = obj["weight_kg"].toDouble();
        int row = static_cast<int>(i) + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        xlsx->write(row, 1, dt.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, dt.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, weightKg,                  rowFmt);
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::readBP(QString startTime, QString endTime)
{
#ifdef Q_OS_ANDROID
    QString status;
    QJniObject result;
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
            bpJsonDoc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = bpJsonDoc.array();
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
#else
    qDebug() << "Not Android";
#endif
}

void Backend::exportBP(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ── Sheet ────────────────────────────────────────────────
    xlsx->addSheet("Blood Pressure Data");
    xlsx->selectSheet("Blood Pressure Data");

    // ── فرمت هدر ─────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#B71C1C"));
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#FFEBEE"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── هدر ستون‌ها ───────────────────────────────────────────
    xlsx->write(1, 1, "Date",               headerFormat);
    xlsx->write(1, 2, "Time",               headerFormat);
    xlsx->write(1, 3, "Systolic (mmHg)",    headerFormat);
    xlsx->write(1, 4, "Diastolic (mmHg)",   headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 18);
    xlsx->setColumnWidth(4, 18);

    // ── داده‌ها ────────────────────────────────────────────────
    QJsonArray arr = bpJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(
                           obj["time"].toString(), Qt::ISODate
                           ).toLocalTime();
        double systolic  = obj["systolic"].toDouble();
        double diastolic = obj["diastolic"].toDouble();
        int row = static_cast<int>(i) + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        xlsx->write(row, 1, dt.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, dt.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, systolic,                  rowFmt);
        xlsx->write(row, 4, diastolic,                 rowFmt);
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::readHR(QString startTime, QString endTime)
{
#ifdef Q_OS_ANDROID
    QString status;
    QJniObject result;
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
            heartRateJsonDoc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = heartRateJsonDoc.array();
            // qDebug() << "💓 Processing" << arr.size() << "heart rate records";
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                heartRateList.append(QPointF(dt.toMSecsSinceEpoch(), obj["bpm"].toDouble()));
            }
        }
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::exportHR(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ── Sheet ────────────────────────────────────────────────
    xlsx->addSheet("Heart Rate Data");
    xlsx->selectSheet("Heart Rate Data");

    // ── فرمت هدر ─────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#E65100"));
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#FFF3E0"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── هدر ستون‌ها ───────────────────────────────────────────
    xlsx->write(1, 1, "Date",      headerFormat);
    xlsx->write(1, 2, "Time",      headerFormat);
    xlsx->write(1, 3, "BPM",       headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 10);

    // ── داده‌ها ────────────────────────────────────────────────
    QJsonArray arr = heartRateJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(
                           obj["time"].toString(), Qt::ISODate
                           ).toLocalTime();
        int bpm = obj["bpm"].toInt();
        int row = static_cast<int>(i) + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        xlsx->write(row, 1, dt.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, dt.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, bpm,                       rowFmt);
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::readBG(QString startTime, QString endTime)
{
#ifdef Q_OS_ANDROID
    QString status;
    QJniObject result;
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
            bloodGlucoseJsonDoc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = bloodGlucoseJsonDoc.array();
            // qDebug() << "🩸 Processing" << arr.size() << "blood glucose records";
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                bloodGlucoseList.append(QPointF(dt.toMSecsSinceEpoch(), obj["glucose"].toDouble()));
            }
        }
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::exportBG(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ── Sheet ────────────────────────────────────────────────
    xlsx->addSheet("Blood Glucose Data");
    xlsx->selectSheet("Blood Glucose Data");

    // ── فرمت هدر ─────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#4A148C"));
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#F3E5F5"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── هدر ستون‌ها ───────────────────────────────────────────
    xlsx->write(1, 1, "Date",             headerFormat);
    xlsx->write(1, 2, "Time",             headerFormat);
    xlsx->write(1, 3, "Glucose (mg/dL)",  headerFormat);
    xlsx->write(1, 4, "Specimen Source",  headerFormat);
    xlsx->write(1, 5, "Meal Type",        headerFormat);
    xlsx->write(1, 6, "Relation to Meal", headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 18);
    xlsx->setColumnWidth(4, 18);
    xlsx->setColumnWidth(5, 14);
    xlsx->setColumnWidth(6, 18);

    // ── label map ها ─────────────────────────────────────────
    static const QStringList specimenLabels = {
        "Unknown", "Interstitial Fluid", "Capillary Blood",
        "Plasma",  "Serum",              "Tears",
        "Whole Blood"
    };
    static const QStringList mealLabels = {
        "Unknown", "Before Meal", "After Meal", "Fasting"
    };
    static const QStringList relationLabels = {
        "Unknown", "Before Meal", "After Meal",
        "Fasting", "General"
    };

    // ── داده‌ها ────────────────────────────────────────────────
    QJsonArray arr = bloodGlucoseJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(
                           obj["time"].toString(), Qt::ISODate
                           ).toLocalTime();
        double  glucose  = obj["glucose"].toDouble();
        int specimen     = obj["specimenSource"].toInt(0);
        int meal         = obj["mealType"].toInt(0);
        int relation     = obj["relationToMeal"].toInt(0);
        int row          = static_cast<int>(i) + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        // safe index access
        QString specimenStr = (specimen >= 0 && specimen < specimenLabels.size())
                                  ? specimenLabels.at(specimen) : "Unknown";
        QString mealStr     = (meal     >= 0 && meal     < mealLabels.size())
                              ? mealLabels.at(meal)         : "Unknown";
        QString relationStr = (relation >= 0 && relation < relationLabels.size())
                                  ? relationLabels.at(relation)  : "Unknown";

        xlsx->write(row, 1, dt.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, dt.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, glucose,                   rowFmt);
        xlsx->write(row, 4, specimenStr,               rowFmt);
        xlsx->write(row, 5, mealStr,                   rowFmt);
        xlsx->write(row, 6, relationStr,               rowFmt);
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::readOxygenSaturation(QString startTime, QString endTime)
{
#ifdef Q_OS_ANDROID
    QString status;
    QJniObject result;

    // ─────────────────────────────────────────
    // Oxygen Saturation (SpO₂)
    // ─────────────────────────────────────────
    {
        QJniObject jStart = QJniObject::fromString(startTime);
        QJniObject jEnd   = QJniObject::fromString(endTime);

        result = QJniObject::callStaticObjectMethod(
            "org/verya/QMLHealthConnect/HealthBridge",
            "readOxygenSaturation",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            jStart.object<jstring>(),
            jEnd.object<jstring>()
            );

        status = result.toString();
        qDebug() << "🫁 Oxygen Saturation status:" << status.left(80);

        if (status == "SECURITY_ERROR") {
            qDebug() << "❌ Security error (oxygen saturation)";
            return;
        }

        if (!status.startsWith("ERROR") && status != "NO_OXYGEN_DATA") {
            oxygenSaturationJsonDoc = QJsonDocument::fromJson(status.toUtf8());
            QJsonArray arr = oxygenSaturationJsonDoc.array();
            //qDebug() << "🫁 Processing" << arr.size() << "oxygen saturation records";
            for (qsizetype i = 0; i < arr.size(); i++) {
                QJsonObject obj = arr.at(i).toObject();
                QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
                double percentage = obj["percentage"].toDouble();
                oxygenSaturationList.append(QPointF(dt.toMSecsSinceEpoch(), percentage));
            }

            qDebug() << "✅ Read" << oxygenSaturationList.size() << "valid SpO2 records";
        }
    }
#else
    qDebug() << "Not Android";
#endif
}

void Backend::exportOxygenSaturation(QXlsx::Document *xlsx)
{
#ifdef Q_OS_ANDROID
    // ── Sheet ────────────────────────────────────────────────
    xlsx->addSheet("Oxygen Saturation Data");
    xlsx->selectSheet("Oxygen Saturation Data");

    // ── فرمت هدر ─────────────────────────────────────────────
    QXlsx::Format headerFormat;
    headerFormat.setFontBold(true);
    headerFormat.setPatternBackgroundColor(QColor("#006064"));
    headerFormat.setFontColor(Qt::white);
    headerFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── فرمت ردیف‌های داده ────────────────────────────────────
    QXlsx::Format dataFormat;
    dataFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    QXlsx::Format oddRowFormat;
    oddRowFormat.setPatternBackgroundColor(QColor("#E0F7FA"));
    oddRowFormat.setHorizontalAlignment(QXlsx::Format::AlignHCenter);

    // ── هدر ستون‌ها ───────────────────────────────────────────
    xlsx->write(1, 1, "Date",                    headerFormat);
    xlsx->write(1, 2, "Time",                    headerFormat);
    xlsx->write(1, 3, "Oxygen Saturation (%)",   headerFormat);

    // ── عرض ستون‌ها ────────────────────────────────────────────
    xlsx->setColumnWidth(1, 14);
    xlsx->setColumnWidth(2, 12);
    xlsx->setColumnWidth(3, 22);

    // ── داده‌ها ────────────────────────────────────────────────
    QJsonArray arr = oxygenSaturationJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(
                           obj["time"].toString(), Qt::ISODate
                           ).toLocalTime();
        double percentage = obj["percentage"].toDouble();
        int row = static_cast<int>(i) + 2;

        QXlsx::Format &rowFmt = (i % 2 == 0) ? oddRowFormat : dataFormat;

        xlsx->write(row, 1, dt.toString("yyyy-MM-dd"), rowFmt);
        xlsx->write(row, 2, dt.toString("hh:mm:ss"),   rowFmt);
        xlsx->write(row, 3, percentage,                rowFmt);
    }
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

void Backend::savePeriodState()
{
    QSettings settings;
    settings.setValue("menstruation/periodActive",
                      periodActive);
    settings.setValue("menstruation/periodStart",
                      currentPeriodStart.toMSecsSinceEpoch());
    settings.sync();
    qDebug() << "💾 Period state saved:"
             << "active=" << periodActive
             << "start=" << currentPeriodStart.toString("yyyy/MM/dd hh:mm:ss");
}

void Backend::loadPeriodState()
{
    QSettings settings;
    periodActive = settings.value("menstruation/periodActive", false).toBool();

    qint64 msec = settings.value("menstruation/periodStart", 0LL).toLongLong();
    if (msec > 0) {
        currentPeriodStart = QDateTime::fromMSecsSinceEpoch(msec);
    }

    qDebug() << "📂 Period state loaded:"
             << "active=" << periodActive
             << "start=" << currentPeriodStart.toString("yyyy/MM/dd hh:mm:ss");

    emit periodStateChanged(periodActive);
}


void Backend::askForPermission(const QStringList &permissions, int requestCode)
{
#ifdef ANDROID
    QJniEnvironment env;
    jobjectArray jPerms = env->NewObjectArray(permissions.size(),
                                              env->FindClass("java/lang/String"),
                                              nullptr);

    for (int i = 0; i < permissions.size(); ++i)
        env->SetObjectArrayElement(jPerms, i,
                                   QJniObject::fromString(permissions[i]).object<jstring>());

    QJniObject::callStaticMethod<void>(
        "org/verya/QMLHealthConnect/MainActivity",
        "requestAppPermissions",
        "([Ljava/lang/String;I)V",
        jPerms,
        requestCode
        );
#endif
}

