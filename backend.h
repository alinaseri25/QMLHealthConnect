#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QTimer>
#include <QPointF>
#include <QRandomGenerator>
#include <QDebug>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QThread>
#include <QDir>
#include "xlsxdocument.h"
#include "xlsxformat.h"
#include "xlsxworksheet.h"

#ifdef Q_OS_ANDROID
#include <QStandardPaths>
#include <QJniObject>
#include <QCoreApplication>
#include <QtCore/qnativeinterface.h>
#include <QJniEnvironment>
#endif

class Backend : public QObject
{
    Q_OBJECT
public:
    explicit Backend(QObject *parent = nullptr);

public slots:
    void onUpdateRequest(bool height,bool weight,bool bp,bool bg,bool hr,bool spo2
                         ,QDateTime startFrom = QDateTime::currentDateTime().addMonths(-1),QDateTime endTo = QDateTime::currentDateTime());
    void onExportRequest(bool height,bool weight,bool bp,bool bg,bool hr,bool spo2);
    void writeHeight(double heightMeters,QDateTime dt = QDateTime::currentDateTime());
    void writeWeight(double weightKg,QDateTime dt = QDateTime::currentDateTime());
    void writeBloodPressure(double systolicMmHg, double diastolicMmHg,QDateTime dt = QDateTime::currentDateTime());
    void writeHeartRate(int bpm,QDateTime dt = QDateTime::currentDateTime());
    void writeBloodGlucose(double glucoseMgDl, int specimenSource = 2,
                           int mealType = 0, int relationToMeal = 0,
                           QDateTime dt = QDateTime::currentDateTime());
    void writeOxygenSaturation(double percentage,QDateTime dt = QDateTime::currentDateTime());

private:
    QString path;
    QList<QPointF> hList;
    QJsonDocument heightJsonDoc;
    QList<QPointF> wList;
    QJsonDocument weightJsonDoc;
    QList<QPointF> bpSystolicList;
    QList<QPointF> bpDiastolicList;
    QJsonDocument bpJsonDoc;
    QList<QPointF> heartRateList;
    QJsonDocument heartRateJsonDoc;
    QList<QPointF> bloodGlucoseList;
    QJsonDocument bloodGlucoseJsonDoc;
    QList<QPointF> oxygenSaturationList;
    QJsonDocument oxygenSaturationJsonDoc;

    bool copyToDownloads(const QString &srcPath, const QString &fileName);
    void loadAvailablePath(void);
    void permissionRequest(void);
    bool checkPermissions(void);
    void readHeight(QString startTime,QString endTime);
    void exportHeight(QXlsx::Document *xlsx);
    void readWeight(QString startTime,QString endTime);
    void exportWeight(QXlsx::Document *xlsx);
    void readBP(QString startTime,QString endTime);
    void exportBP(QXlsx::Document *xlsx);
    void readHR(QString startTime,QString endTime);
    void exportHR(QXlsx::Document *xlsx);
    void readBG(QString startTime,QString endTime);
    void exportBG(QXlsx::Document *xlsx);
    void readOxygenSaturation(QString startTime, QString endTime);
    void exportOxygenSaturation(QXlsx::Document *xlsx);
    static QString isoStringMonthsAgo(int months);

signals:
    void newDataRead(QList<QPointF> hList,
                     QList<QPointF> wList,
                     QList<QPointF> bpSystolicList, QList<QPointF> bpDiastolicList,
                     QList<QPointF> heartRateList,
                     QList<QPointF> bloodGlucoseList,
                     QList<QPointF> oxygenSaturationList);
    void exportCompleted(bool success, QString message);
    void heightWritten(bool success, QString message);
    void weightWritten(bool success, QString message);
    void bloodPressureWritten(bool success, QString message);
    void heartRateWritten(bool success, QString message);
    void bloodGlucoseWritten(bool success, QString message);
    void oxygenSaturationWritten(bool success, QString message);
};

#endif // BACKEND_H
