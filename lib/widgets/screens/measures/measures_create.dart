import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rebloc/rebloc.dart';
import 'package:tailor_made/constants/mk_style.dart';
import 'package:tailor_made/models/measure.dart';
import 'package:tailor_made/rebloc/actions/measures.dart';
import 'package:tailor_made/rebloc/states/main.dart';
import 'package:tailor_made/rebloc/view_models/measures.dart';
import 'package:tailor_made/services/cloud_db.dart';
import 'package:tailor_made/utils/mk_choice_dialog.dart';
import 'package:tailor_made/utils/mk_dispatch_provider.dart';
import 'package:tailor_made/utils/mk_navigate.dart';
import 'package:tailor_made/utils/mk_snackbar_provider.dart';
import 'package:tailor_made/utils/mk_theme.dart';
import 'package:tailor_made/widgets/_partials/mk_app_bar.dart';
import 'package:tailor_made/widgets/_partials/mk_clear_button.dart';
import 'package:tailor_made/widgets/_partials/mk_close_button.dart';
import 'package:tailor_made/widgets/screens/measures/_views/measure_dialog.dart';

class MeasuresCreate extends StatefulWidget {
  const MeasuresCreate({
    Key key,
    this.measures,
    this.groupName,
    this.unitValue,
  }) : super(key: key);

  final List<MeasureModel> measures;
  final String groupName, unitValue;

  @override
  _MeasuresCreateState createState() => _MeasuresCreateState();
}

class _MeasuresCreateState extends State<MeasuresCreate>
    with MkSnackBarProvider, MkDispatchProvider<AppState> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _autovalidate = false;
  String groupName, unitValue;
  List<MeasureModel> measures;
  final FocusNode _unitNode = FocusNode();

  @override
  void initState() {
    super.initState();
    measures = widget.measures ?? <MeasureModel>[];
    groupName = widget.groupName ?? "";
    unitValue = widget.unitValue ?? "";
  }

  @override
  void dispose() {
    _unitNode.dispose();
    super.dispose();
  }

  @override
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return ViewModelSubscriber<AppState, MeasuresViewModel>(
      converter: (store) => MeasuresViewModel(store),
      builder: (
        BuildContext context,
        DispatchFunction dispatcher,
        MeasuresViewModel vm,
      ) {
        final List<Widget> children = [];

        children.add(const _Header(title: "Group Name"));
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextFormField(
            initialValue: groupName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onEditingComplete: () =>
                FocusScope.of(context).requestFocus(_unitNode),
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              isDense: true,
              hintText: "eg Blouse",
            ),
            validator: (value) =>
                (value.isNotEmpty) ? null : "Please input a name",
            onSaved: (value) => groupName = value.trim(),
          ),
        ));

        children.add(const _Header(title: "Group Unit"));
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextFormField(
            focusNode: _unitNode,
            initialValue: unitValue,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              isDense: true,
              hintText: "Unit (eg. In, cm)",
            ),
            validator: (value) =>
                (value.isNotEmpty) ? null : "Please input a value",
            onSaved: (value) => unitValue = value.trim(),
          ),
        ));

        if (measures.isNotEmpty) {
          children.add(const _Header(title: "Group Items"));
          children.add(
            _GroupItems(
              measures: measures,
              onPressed: (MeasureModel measure) {
                if (measure?.reference != null) {
                  _onTapDeleteItem(vm, measure);
                }
                setState(() {
                  // TODO: test this
                  measures = measures..removeWhere((_) => _ == measure);
                });
              },
            ),
          );

          children.add(const SizedBox(height: 84.0));
        }

        return Scaffold(
          resizeToAvoidBottomPadding: false,
          key: scaffoldKey,
          appBar: MkAppBar(
            title: const Text(""),
            leading: const MkCloseButton(),
            actions: [
              MkClearButton(
                color: Colors.black,
                child: const Text("SAVE"),
                onPressed: measures.isEmpty ? null : () => _handleSubmit(vm),
              )
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                autovalidate: _autovalidate,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add_circle_outline),
            backgroundColor: Colors.white,
            foregroundColor: kAccentColor,
            label: const Text("Add Item"),
            onPressed: _handleAddItem,
          ),
        );
      },
    );
  }

  void _onTapDeleteItem(MeasuresViewModel vm, MeasureModel measure) async {
    final choice = await mkChoiceDialog(
      context: context,
      message: "Are you sure?",
    );
    if (choice == null || choice == false) {
      return;
    }

    showLoadingSnackBar();

    try {
      dispatchAction(const ToggleMeasuresLoading());
      await measure.reference.delete();
      closeLoadingSnackBar();
    } catch (e) {
      closeLoadingSnackBar();
      showInSnackBar(e.toString());
    }
  }

  void _handleAddItem() async {
    if (_isOkForm()) {
      final _measure = await Navigator.push<MeasureModel>(
        context,
        MkNavigate.fadeIn<MeasureModel>(
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            backgroundColor: Colors.black38,
            body: MeasureDialog(
              measure: MeasureModel(
                name: "",
                group: groupName,
                unit: unitValue,
              ),
            ),
          ),
        ),
      );

      if (_measure == null) {
        return;
      }

      setState(() {
        measures = [_measure]..addAll(measures);
      });
    }
  }

  void _handleSubmit(MeasuresViewModel vm) async {
    if (_isOkForm()) {
      final WriteBatch batch = CloudDb.instance.batch();

      measures.forEach((measure) {
        if (measure?.reference != null) {
          batch.updateData(
            measure.reference,
            <String, String>{
              "group": groupName,
              "unit": unitValue,
            },
          );
        } else {
          batch.setData(
            CloudDb.measurements.document(measure.id),
            measure.toMap(),
            merge: true,
          );
        }
      });

      showLoadingSnackBar();
      try {
        dispatchAction(const ToggleMeasuresLoading());
        await batch.commit();

        closeLoadingSnackBar();
        Navigator.pop(context);
      } catch (e) {
        closeLoadingSnackBar();
        showInSnackBar(e.toString());
      }
    }
  }

  bool _isOkForm() {
    final FormState form = _formKey.currentState;
    if (form == null) {
      return false;
    }
    if (!form.validate()) {
      _autovalidate = true; // Start validating on every change.
      return false;
    } else {
      form.save();
      return true;
    }
  }
}

class _GroupItems extends StatelessWidget {
  const _GroupItems({
    Key key,
    @required this.measures,
    @required this.onPressed,
  }) : super(key: key);

  final List<MeasureModel> measures;
  final ValueSetter<MeasureModel> onPressed;

  @override
  Widget build(BuildContext context) {
    final items = List.generate(measures.length, (index) {
      final measure = measures[index];
      return ListTile(
        dense: true,
        title: Text(measure.name),
        subtitle: Text(measure.unit),
        trailing: IconButton(
          icon: Icon(
            measure?.reference != null
                ? Icons.delete
                : Icons.remove_circle_outline,
          ),
          iconSize: 20.0,
          onPressed: () => onPressed(measure),
        ),
      );
    });
    return Column(
      children: items.toList(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    Key key,
    @required this.title,
    this.trailing,
  }) : super(key: key);

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100].withOpacity(.4),
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.only(
        top: 8.0,
        bottom: 8.0,
        left: 16.0,
        right: 16.0,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: MkTheme.of(context).small,
          ),
          Text(
            trailing,
            style: MkTheme.of(context).small,
          ),
        ],
      ),
    );
  }
}
