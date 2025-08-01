//
//  PhotoPickerView+Function.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/9/17.
//

import UIKit

extension PhotoPickerView {
    
    func initViews() {
        verticalLayout = PhotoPickerSwitchLayout()
        verticalLayout.scrollDirection = .vertical
        
        horizontalLayout = PhotoPickerSwitchLayout()
        horizontalLayout.scrollDirection = .horizontal
        
        collectionView = HXCollectionView(
            frame: bounds,
            collectionViewLayout: scrollDirection == .vertical ? verticalLayout : horizontalLayout
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        if let customSingleCellClass = config.cell.customSingleCellClass {
            collectionView.register(
                customSingleCellClass,
                forCellWithReuseIdentifier:
                    NSStringFromClass(
                        PhotoPickerViewCell.classForCoder()
                    )
            )
        }else {
            collectionView.register(
                PhotoPickerViewCell.self,
                forCellWithReuseIdentifier:
                    NSStringFromClass(
                        PhotoPickerViewCell.classForCoder()
                    )
            )
        }
        if let customSelectableCellClass = config.cell.customSelectableCellClass {
            collectionView.register(
                customSelectableCellClass,
                forCellWithReuseIdentifier:
                    NSStringFromClass(
                        PhotoPickerSelectableViewCell.classForCoder()
                    )
            )
        }else {
            collectionView.register(
                PhotoPickerSelectableViewCell.self,
                forCellWithReuseIdentifier:
                    NSStringFromClass(
                        PhotoPickerSelectableViewCell.classForCoder()
                    )
            )
        }
        if config.allowAddCamera {
            #if !targetEnvironment(macCatalyst)
            collectionView.register(
                PickerCameraViewCell.self,
                forCellWithReuseIdentifier:
                    NSStringFromClass(PickerCameraViewCell.classForCoder())
            )
            #endif
        }
        if config.allowAddLimit && AssetPermissionsUtil.isLimitedAuthorizationStatus {
            collectionView.register(
                PhotoPickerLimitCell.self,
                forCellWithReuseIdentifier:
                    NSStringFromClass(PhotoPickerLimitCell.classForCoder())
            )
        }
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        }
        
        emptyView = PhotoPickerEmptyView(config: config.emptyView)
        
        manager.config.notAuthorized.isHiddenCloseButton = true
        deniedView = DeniedAuthorizationView(config: manager.config)
        
        panGR = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerClick(pan:)))
        if scrollDirection == .horizontal {
            panGR.isEnabled = dragEnable
        }else {
            panGR.isEnabled = false
        }
        
        dragView = UIImageView()
        dragView.clipsToBounds = true
        dragView.contentMode = .scaleAspectFill
        
        addSubview(collectionView)
        let isDark = PhotoManager.isDark
        backgroundColor = isDark ? config.backgroundDarkColor : config.backgroundColor
        collectionView.backgroundColor = isDark ? config.backgroundDarkColor : config.backgroundColor
        callBack()
        addGestureRecognizer(panGR)
    }
    
    
    func callBack() {
        manager.willSelectAsset = { [weak self] in
            guard let self = self else { return }
            self.delegate?.photoPickerView(self, willSelectAsset: $0, at: $1)
        }
        manager.didSelectAsset = { [weak self] in
            guard let self = self else { return }
            self.delegate?.photoPickerView(self, didSelectAsset: $0, at: $1)
        }
        manager.willDeselectAsset = { [weak self] in
            guard let self = self else { return }
            self.delegate?.photoPickerView(self, willDeselectAsset: $0, at: $1)
        }
        manager.didDeselectAsset = { [weak self] in
            guard let self = self else { return }
            self.delegate?.photoPickerView(self, didDeselectAsset: $0, at: $1)
        }
    }
    
    func setupEmptyView() {
        if config.allowAddLimit && AssetPermissionsUtil.isLimitedAuthorizationStatus {
            emptyView.removeFromSuperview()
            return
        }
        if assets.isEmpty {
            collectionView.addSubview(emptyView)
        }else {
            emptyView.removeFromSuperview()
        }
    }
    
    func setupDeniedView() {
        emptyView.removeFromSuperview()
        if AssetPermissionsUtil.authorizationStatus == .denied {
            collectionView.addSubview(deniedView)
        }else {
            deniedView.removeFromSuperview()
        }
    }
    func scrollToCenter(for photoAsset: PhotoAsset?) {
        if assets.isEmpty {
            return
        }
        if let photoAsset = photoAsset,
           var item = assets.firstIndex(of: photoAsset) {
            if needOffset {
                item += offsetIndex
            }
            collectionView.scrollToItem(
                at: IndexPath(item: item, section: 0),
                at: scrollDirection == .vertical ? .centeredVertically : .centeredHorizontally,
                animated: false
            )
            DispatchQueue.main.async {
                self.scrollViewDidScroll(self.collectionView)
            }
        }
    }
    func scrollCellToVisibleArea(_ cell: PhotoPickerBaseViewCell) {
        if assets.isEmpty {
            return
        }
        let rect = cell.photoView.convert(cell.photoView.bounds, to: self)
        if scrollDirection == .vertical {
            if rect.minY - contentInset.top < 0 {
                if let indexPath = collectionView.indexPath(for: cell) {
                    collectionView.scrollToItem(
                        at: indexPath,
                        at: .top,
                        animated: false
                    )
                }
            }else if rect.maxY > height - contentInset.bottom {
                if let indexPath = collectionView.indexPath(for: cell) {
                    collectionView.scrollToItem(
                        at: indexPath,
                        at: .bottom,
                        animated: false
                    )
                }
            }
        }else {
            if rect.minX - contentInset.left < 0 {
                if let indexPath = collectionView.indexPath(for: cell) {
                    collectionView.scrollToItem(
                        at: indexPath,
                        at: .left,
                        animated: false
                    )
                }
            }else if rect.maxX > width - contentInset.right {
                if let indexPath = collectionView.indexPath(for: cell) {
                    collectionView.scrollToItem(
                        at: indexPath,
                        at: .right,
                        animated: false
                    )
                }
            }
        }
        DispatchQueue.main.async {
            self.scrollViewDidScroll(self.collectionView)
        }
    }
    func scrollToAppropriatePlace(photoAsset: PhotoAsset?) {
        var item = config.sort == .asc ? assets.count - 1 : 0
        if let photoAsset = photoAsset {
            if let index = assets.firstIndex(of: photoAsset) {
                item = index
            }
            if needOffset {
                item += offsetIndex
            }
        }
        collectionView.scrollToItem(
            at: IndexPath(
                item: item,
                section: 0
            ),
            at: scrollDirection == .vertical ? .centeredVertically : .centeredHorizontally,
            animated: false
        )
        DispatchQueue.main.async {
            self.scrollViewDidScroll(self.collectionView)
        }
    }
    func getCell(
        for item: Int
    ) -> PhotoPickerBaseViewCell? {
        if assets.isEmpty {
            return nil
        }
        let cell = collectionView.cellForItem(
            at: IndexPath(item: item, section: 0)
        ) as? PhotoPickerBaseViewCell
        return cell
    }
    func getCell(
        for photoAsset: PhotoAsset
    ) -> PhotoPickerBaseViewCell? {
        if let item = getIndexPath(for: photoAsset)?.item {
            return getCell(for: item)
        }
        return nil
    }
    func getIndexPath(for photoAsset: PhotoAsset) -> IndexPath? {
        if assets.isEmpty {
            return nil
        }
        if var item = assets.firstIndex(of: photoAsset) {
            if needOffset {
                item += offsetIndex
            }
            return IndexPath(item: item, section: 0)
        }
        return nil
    }
    func reloadCell(for photoAsset: PhotoAsset) {
        if let indexPath = getIndexPath(for: photoAsset) {
            collectionView.reloadItems(at: [indexPath])
        }
    }
    func resetICloud(for photoAsset: PhotoAsset) {
        guard let cell = getCell(for: photoAsset),
              cell.inICloud else {
            return
        }
        cell.requestICloudState()
    }
    func getPhotoAsset(for index: Int) -> PhotoAsset {
        var photoAsset: PhotoAsset
        if needOffset {
            photoAsset = assets[index - offsetIndex]
        }else {
            photoAsset = assets[index]
        }
        return photoAsset
    }
    func addedPhotoAsset(for photoAsset: PhotoAsset) {
        let indexPath: IndexPath
        if config.sort == .desc {
            assets.insert(photoAsset, at: 0)
            indexPath = IndexPath(
                item: needOffset ? offsetIndex : 0,
                section: 0
            )
        }else {
            assets.append(photoAsset)
            indexPath = IndexPath(
                item: assets.count - 1,
                section: 0
            )
        }
        collectionView.insertItems(
            at: [indexPath]
        )
        collectionView.scrollToItem(
            at: indexPath,
            at: .bottom,
            animated: true
        )
    }
    func updateCellSelectedTitle() {
        for visibleCell in collectionView.visibleCells {
            if visibleCell is PhotoPickerBaseViewCell,
               let photoAsset = (visibleCell as? PhotoPickerBaseViewCell)?.photoAsset {
                let cell = visibleCell as! PhotoPickerBaseViewCell
                if !photoAsset.isSelected &&
                    config.cell.isShowDisableMask &&
                    manager.config.maximumSelectedVideoFileSize == 0  &&
                    manager.config.maximumSelectedPhotoFileSize == 0 {
                    cell.canSelect = manager.canSelectAsset(
                        for: photoAsset,
                        showHUD: false
                    )
                }
                cell.updateSelectedState(
                    isSelected: photoAsset.isSelected,
                    animated: false
                )
            }
        }
    }
    
    func updateCellSelectedState(for item: Int, isSelected: Bool) {
        if item >= assets.count && !needOffset {
            return
        }
        var showHUD = false
        let photoAsset = getPhotoAsset(for: item)
        if photoAsset.isSelected != isSelected {
            if isSelected {
                func addAsset(showTip: Bool) {
                    if manager.canSelectAsset(for: photoAsset, showHUD: showTip) {
                        manager.addedPhotoAsset(photoAsset: photoAsset)
                        if let cell = getCell(for: item) {
                            cell.updateSelectedState(isSelected: isSelected, animated: false)
                        }
                        updateCellSelectedTitle()
                    }else {
                        showHUD = true
                    }
                }
                let inICloud = photoAsset.checkICloundStatus(
                    allowSyncPhoto: manager.config.allowSyncICloudWhenSelectPhoto,
                    hudAddedTo: self,
                    completion: { _, isSuccess in
                    if isSuccess {
                        addAsset(showTip: true)
                    }
                })
                if !inICloud {
                    addAsset(showTip: false)
                }
            }else {
                manager.removePhotoAsset(photoAsset: photoAsset)
                if let cell = getCell(for: item) {
                    cell.updateSelectedState(isSelected: isSelected, animated: false)
                }
                updateCellSelectedTitle()
            }
        }
        if manager.selectArrayIsFull() && showHUD {
            PhotoManager.HUDView.showInfo(with: .textManager.picker.maximumSelectedHudTitle.text, delay: 1.5, animated: true, addedTo: UIApplication.shared.keyWindow)
        }
    }
    
    @objc
    func panGestureRecognizerClick(pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            dragTempCell?.isHidden = false
            dragTempCell = nil
            let point = pan.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: point),
               let cell = collectionView.cellForItem(at: indexPath) as? PhotoPickerBaseViewCell {
                if let pickerCell = cell as? PhotoPickerViewCell,
                   pickerCell.inICloud {
                    return
                }
                dragView.image = cell.photoView.image
                let keyWindow = UIApplication.shared.keyWindow
                let rect = cell.convert(cell.photoView.frame, to: keyWindow)
                dragView.frame = rect
                keyWindow?.addSubview(dragView)
                initialDragRect = rect
                cell.isHidden = true
                dragTempCell = cell
                delegate?.photoPickerView(self, gestureRecognizer: pan, beginDrag: cell.photoAsset, dragView: dragView)
            }
        case .changed:
            if let cell = dragTempCell {
                let point = pan.translation(in: self)
                dragView.y = initialDragRect.minY + point.y
                delegate?.photoPickerView(self, gestureRecognizer: pan, changeDrag: cell.photoAsset)
            }
        case .ended, .cancelled, .failed:
            if let cell = dragTempCell {
                if let isAnimation = delegate?.photoPickerView(self, gestureRecognizer: pan, endDrag: cell.photoAsset),
                   !isAnimation {
                    dragTempCell?.isHidden = false
                    dragTempCell = nil
                    dragView.removeFromSuperview()
                    return
                }
                UIView.animate(withDuration: 0.25) {
                    self.dragView.frame = self.initialDragRect
                } completion: { _ in
                    if pan.state == .began || pan.state == .changed {
                        return
                    }
                    self.dragTempCell?.isHidden = false
                    self.dragTempCell = nil
                    self.dragView.removeFromSuperview()
                }
                
            }
        default:
            break
        }
    }
    
    func finishSelectionAsset(_ photoAssets: [PhotoAsset]) {
        let result = PickerResult(photoAssets: photoAssets, isOriginal: isOriginal)
        delegate?.photoPickerView(self, didFinishSelection: result)
        delegate?.photoPickerView(self, dismissCompletion: result)
    }
}
