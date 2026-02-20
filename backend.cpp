#include "backend.h"

Backend::Backend(QObject *parent)
    : QObject{parent}
{
    loadAvailablePath();
    checkPermissions();
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

    qDebug() << "📅 Time range:" << startTime << "→" << endTime;

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

    emit newDataRead(hList, wList, bpSystolicList, bpDiastolicList, heartRateList, bloodGlucoseList, oxygenSaturationList);
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
    QString currentTime = dt.toString(Qt::ISODateWithMs);
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
    QString currentTime = dt.toString(Qt::ISODateWithMs);
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
    QString currentTime = dt.toString(Qt::ISODateWithMs);
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
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        qDebug() << "❌ Context invalid";
        return false;
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
    if (!permStatus.contains("ALL_GRANTED (10/10)"))
    {
        qDebug() << "⚠️ Requesting permissions...";
        permissionRequest();
        qDebug() << "💡 Grant permissions and press Read again";
        return false;
    }

    return true;
#else
    qDebug() << "Not Android";
#endif
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
    xlsx->addSheet("Height Data");
    xlsx->selectSheet("Height Data");
    xlsx->write(1,1,QString("Date Time"));
    xlsx->write(1,2,"Height (m)");

    QJsonArray arr = heightJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        xlsx->write(i + 2,1,dt.toString("yyyy/MM/dd hh:mm:ss"));
        xlsx->write(i + 2,2,obj["height_m"].toDouble());
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
    xlsx->addSheet("Weight Data");
    xlsx->selectSheet("Weight Data");
    xlsx->write(1,1,QString("Date Time"));
    xlsx->write(1,2,"Weight (Kg)");

    QJsonArray arr = weightJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        xlsx->write(i + 2,1,dt.toString("yyyy/MM/dd hh:mm:ss"));
        xlsx->write(i + 2,2,obj["weight_kg"].toDouble());
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
    xlsx->addSheet("Blood Perssure Data");
    xlsx->selectSheet("Blood Perssure Data");
    xlsx->write(1,1,QString("Date Time"));
    xlsx->write(1,2,"systolic (mmHg)");
    xlsx->write(1,3,"diastolic (mmHg)");
    QJsonArray arr = bpJsonDoc.array();
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        xlsx->write(i + 2,1,dt.toString("yyyy/MM/dd hh:mm:ss"));
        xlsx->write(i + 2,2,obj["systolic"].toDouble());
        xlsx->write(i + 2,3,obj["diastolic"].toDouble());
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
    xlsx->addSheet("Heart Reat Data");
    xlsx->selectSheet("Heart Reat Data");
    xlsx->write(1,1,QString("Date Time"));
    xlsx->write(1,2,"Heart Reat (bpm)");
    QJsonArray arr = heartRateJsonDoc.array();
    // qDebug() << "💓 Processing" << arr.size() << "heart rate records";
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        xlsx->write(i + 2,1,dt.toString("yyyy/MM/dd hh:mm:ss"));
        xlsx->write(i + 2,2,obj["bpm"].toDouble());
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
                bloodGlucoseList.append(QPointF(dt.toMSecsSinceEpoch(), obj["glucose_mg_dl"].toDouble()));
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
    xlsx->addSheet("Blood Glucose Data");
    xlsx->selectSheet("Blood Glucose Data");
    xlsx->write(1,1,QString("Date Time"));
    xlsx->write(1,2,"Blood Glucose (md/dl)");
    QJsonArray arr = bloodGlucoseJsonDoc.array();
    // qDebug() << "🩸 Processing" << arr.size() << "blood glucose records";
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        xlsx->write(i + 2,1,dt.toString("yyyy/MM/dd hh:mm:ss"));
        xlsx->write(i + 2,2,obj["glucose_mg_dl"].toDouble());
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
    xlsx->addSheet("Oxygen Saturation Data");
    xlsx->selectSheet("Oxygen Saturation Data");
    xlsx->write(1,1,QString("Date Time"));
    xlsx->write(1,2,"Oxygen Saturation Data (%)");
    QJsonArray arr = oxygenSaturationJsonDoc.array();
    //qDebug() << "🫁 Processing" << arr.size() << "oxygen saturation records";
    for (qsizetype i = 0; i < arr.size(); i++) {
        QJsonObject obj = arr.at(i).toObject();
        QDateTime dt = QDateTime::fromString(obj["time"].toString(), Qt::ISODate);
        double percentage = obj["percentage"].toDouble();
        xlsx->write(i + 2,1,dt.toString("yyyy/MM/dd hh:mm:ss"));
        xlsx->write(i + 2,2,percentage);
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
