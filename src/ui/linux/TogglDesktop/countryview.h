#ifndef COUNTRYVIEW_H
#define COUNTRYVIEW_H

#include <QObject>
#include <QVector>

#include "toggl.h"

class CountryView : public QObject
{
    Q_OBJECT

public:
    explicit CountryView(QObject *parent = 0);

    static QVector<CountryView *> importAll(TogglCountryView *first) {
        QVector<CountryView *> result;
        TogglCountryView *it = first;
        while (it) {
            CountryView *view = new CountryView();
            view->ID = it->ID;
            view->VatApplicable = it->VatApplicable;
            view->Text = toQString(it->Name);
            view->Name = toQString(it->Name);
            result.push_back(view);
            view->Name = toQString(it->VatPercentage);
            view->Name = toQString(it->VatRegex);
            view->Name = toQString(it->Code);
            it = static_cast<TogglCountryView *>(it->Next);
        }
        return result;
    }

    uint64_t ID;
    QString Text;
    QString Name;
    bool VatApplicable;
    QString VatPercentage;
    QString VatRegex;
    QString Code;

signals:

public slots:

};

#endif // COUNTRYVIEW_H
