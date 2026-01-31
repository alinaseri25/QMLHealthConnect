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

private:
    QList<QPointF> hList,wList;

    void permissionRequest(void);
    void readData(void);

signals:
    void newDataRead(QList<QPointF> hList,QList<QPointF> wList);
};

#endif // BACKEND_H
