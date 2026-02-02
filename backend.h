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
#include <QJniObject>

#ifdef Q_OS_ANDROID
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
    void onUpdateRequest(void);
    void writeHeight(double heightMeters);
    void writeWeight(double weightKg);
    void writeBloodPressure(double systolicMmHg, double diastolicMmHg);

private:
    QList<QPointF> hList,wList;
    QList<QPointF> bpSystolicList;
    QList<QPointF> bpDiastolicList;

    void permissionRequest(void);
    void readData(void);

signals:
    void newDataRead(QList<QPointF> hList, QList<QPointF> wList,
                     QList<QPointF> bpSystolicList, QList<QPointF> bpDiastolicList);
    void heightWritten(bool success, QString message);
    void weightWritten(bool success, QString message);
    void bloodPressureWritten(bool success, QString message);
};

#endif // BACKEND_H
