




class MRLLineItemDialog(QDialog):
    def __init__(self, db_manager):
        super(MRLLineItemDialog, self).__init__()
        self.db_manager = db_manager
        uic.loadUi('mrl_line_item_dialog.ui', self)
        # Rest of your initialization code...

